/**
 * x402 Payment Middleware for Fastify
 *
 * Implements the x402 HTTP 402 Payment Required protocol on Stacks.
 * Uses the x402-stacks library's V2 verifier with an external facilitator
 * to verify and settle payments.
 *
 * Flow:
 * 1. Client requests a gated endpoint (no payment header) → 402 + payment-required header
 * 2. Client signs a transaction, retries with payment-signature header
 * 3. Middleware sends the signed tx to the facilitator for settlement
 * 4. If settlement succeeds → continue to route handler
 */
import { FastifyRequest, FastifyReply } from 'fastify';
import {
  X402PaymentVerifier,
  X402_HEADERS,
  X402_ERROR_CODES,
  STXtoMicroSTX,
  BTCtoSats,
  USDCxToMicroUSDCx,
  networkToCAIP2,
  type PaymentRequiredV2,
  type PaymentPayloadV2,
  type PaymentRequirementsV2,
  type SettlementResponseV2,
  type NetworkV2,
} from 'x402-stacks';
import { config } from '../../config.js';
import pino from 'pino';

const logger = pino({ name: 'x402' });

// Default facilitator for Stacks x402
const DEFAULT_FACILITATOR = 'https://x402-backend-7eby.onrender.com';

export interface X402RouteConfig {
  /** Payment amount in human units (e.g. 0.001 STX) */
  amount: number;
  /** Token type */
  asset: 'STX' | 'sBTC' | 'USDCx';
  /** Description of the protected resource */
  description?: string;
  /** MIME type of the response */
  mimeType?: string;
}

/**
 * Convert human-readable amount to atomic units based on asset type
 */
function toAtomicAmount(amount: number, asset: 'STX' | 'sBTC' | 'USDCx'): string {
  switch (asset) {
    case 'STX': return STXtoMicroSTX(amount).toString();
    case 'sBTC': return BTCtoSats(amount).toString();
    case 'USDCx': return USDCxToMicroUSDCx(amount).toString();
  }
}

/**
 * Get the CAIP-2 asset identifier
 */
function getAssetId(asset: 'STX' | 'sBTC' | 'USDCx'): string {
  switch (asset) {
    case 'STX': return 'STX';
    case 'sBTC': return 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token';
    case 'USDCx': return 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdcx';
  }
}

/**
 * The wallet address that receives x402 payments (deployer address)
 */
const PAY_TO_ADDRESS = config.deployerAddress;

/**
 * Creates a Fastify preHandler hook that gates a route with x402 payment
 */
export function x402PaymentHook(routeConfig: X402RouteConfig) {
  const facilitatorUrl = process.env.X402_FACILITATOR_URL || DEFAULT_FACILITATOR;
  const verifier = new X402PaymentVerifier(facilitatorUrl);
  const networkStr = config.stacksNetwork === 'mainnet' ? 'mainnet' : 'testnet';
  const network: NetworkV2 = networkToCAIP2(networkStr);
  const atomicAmount = toAtomicAmount(routeConfig.amount, routeConfig.asset);
  const assetId = getAssetId(routeConfig.asset);

  return async (request: FastifyRequest, reply: FastifyReply) => {
    // Check if x402 is disabled via env var
    if (process.env.X402_ENABLED === 'false') {
      return; // Skip payment — continue to handler
    }

    const paymentSignatureHeader = request.headers['payment-signature'] as string | undefined;

    if (!paymentSignatureHeader) {
      // No payment — return 402 with payment requirements
      const paymentRequired: PaymentRequiredV2 = {
        x402Version: 2,
        resource: {
          url: `${request.protocol}://${request.hostname}${request.url}`,
          description: routeConfig.description,
          mimeType: routeConfig.mimeType || 'application/json',
        },
        accepts: [{
          scheme: 'exact',
          network,
          amount: atomicAmount,
          asset: assetId,
          payTo: PAY_TO_ADDRESS,
          maxTimeoutSeconds: 300,
        }],
      };

      const encoded = Buffer.from(JSON.stringify(paymentRequired)).toString('base64');

      reply
        .header('payment-required', encoded)
        .code(402)
        .send(paymentRequired);
      return reply;
    }

    // Decode payment payload from header
    let paymentPayload: PaymentPayloadV2;
    try {
      const decoded = Buffer.from(paymentSignatureHeader, 'base64').toString('utf-8');
      paymentPayload = JSON.parse(decoded);
    } catch {
      reply.code(400).send({
        error: X402_ERROR_CODES.INVALID_PAYLOAD,
        message: 'Invalid payment-signature header',
      });
      return reply;
    }

    // Validate x402 version
    if (paymentPayload.x402Version !== 2) {
      reply.code(400).send({
        error: X402_ERROR_CODES.INVALID_X402_VERSION,
        message: 'Only x402 v2 is supported',
      });
      return reply;
    }

    // Settle payment via facilitator
    const paymentRequirements: PaymentRequirementsV2 = {
      scheme: 'exact',
      network,
      amount: atomicAmount,
      asset: assetId,
      payTo: PAY_TO_ADDRESS,
      maxTimeoutSeconds: 300,
    };

    try {
      const settlement: SettlementResponseV2 = await verifier.settle(paymentPayload, {
        paymentRequirements,
      });

      if (!settlement.success) {
        logger.warn({ error: settlement.errorReason, payer: settlement.payer }, 'x402 settlement failed');

        const paymentRequired: PaymentRequiredV2 = {
          x402Version: 2,
          error: settlement.errorReason || 'Payment settlement failed',
          resource: {
            url: `${request.protocol}://${request.hostname}${request.url}`,
          },
          accepts: [paymentRequirements],
        };
        const encoded = Buffer.from(JSON.stringify(paymentRequired)).toString('base64');

        reply
          .header('payment-required', encoded)
          .code(402)
          .send({
            error: settlement.errorReason || X402_ERROR_CODES.UNEXPECTED_SETTLE_ERROR,
            payer: settlement.payer,
            transaction: settlement.transaction,
          });
        return reply;
      }

      // Payment settled successfully — attach to request and continue
      logger.info({
        payer: settlement.payer,
        tx: settlement.transaction,
        amount: routeConfig.amount,
        asset: routeConfig.asset,
      }, 'x402 payment settled');

      // Attach payment info to request for route handler
      (request as any).x402Payment = settlement;

      // Set payment-response header
      const paymentResponse = {
        success: settlement.success,
        payer: settlement.payer,
        transaction: settlement.transaction,
        network: settlement.network,
      };
      reply.header(
        'payment-response',
        Buffer.from(JSON.stringify(paymentResponse)).toString('base64')
      );

      // Don't return — Fastify proceeds to route handler
    } catch (error) {
      logger.error({ error }, 'x402 settlement error');
      reply.code(500).send({
        error: 'Payment settlement failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      return reply;
    }
  };
}
