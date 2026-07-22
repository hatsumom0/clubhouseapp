import { createPublicClient, http, recoverMessageAddress } from "viem";
import { apeChain, mainnet } from "viem/chains";

/**
 * Server-side signature verification for BAYC Clubhouse Glyph login.
 *
 * POST /verify  { address, message, signature }
 *   → { valid: boolean, method?: "eoa" | "erc1271:<chainId>" }
 *
 * Verifies an EIP-191 personal_sign signature:
 *  1. EOA fast path — offline ecrecover, no RPC.
 *  2. Smart-wallet path — ERC-1271/ERC-6492 via viem's universal validator
 *     on ApeChain (Glyph smart wallets) and Ethereum mainnet.
 *
 * The app calls this after the Glyph callback and refuses the session if
 * the proof doesn't verify. A future door/QR backend should call the same
 * endpoint to validate membership proofs.
 *
 * Every other request falls through to the static bridge assets.
 */

interface Env {
  ASSETS: Fetcher;
}

const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
// ERC-6492 wrapped signatures can be long; cap generously.
const SIGNATURE_RE = /^0x[0-9a-fA-F]{2,16384}$/;
const MAX_MESSAGE_LENGTH = 10_000;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

async function verifySignature(
  address: `0x${string}`,
  message: string,
  signature: `0x${string}`
): Promise<{ valid: boolean; method?: string }> {
  // 1) EOA: offline recovery
  try {
    const recovered = await recoverMessageAddress({ message, signature });
    if (recovered.toLowerCase() === address.toLowerCase()) {
      return { valid: true, method: "eoa" };
    }
  } catch {
    // not a plain EOA signature — fall through to contract verification
  }

  // 2) Smart wallets (ERC-1271, incl. pre-deploy ERC-6492)
  for (const chain of [apeChain, mainnet]) {
    try {
      const client = createPublicClient({ chain, transport: http() });
      const valid = await client.verifyMessage({ address, message, signature });
      if (valid) return { valid: true, method: `erc1271:${chain.id}` };
    } catch {
      // RPC hiccup on one chain must not validate — try the next
    }
  }

  return { valid: false };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/verify") {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: CORS_HEADERS });
      }
      if (request.method !== "POST") {
        return json({ error: "POST only" }, 405);
      }

      let body: { address?: string; message?: string; signature?: string };
      try {
        body = await request.json();
      } catch {
        return json({ error: "invalid JSON" }, 400);
      }

      const { address, message, signature } = body;
      if (
        typeof address !== "string" ||
        !ADDRESS_RE.test(address) ||
        typeof signature !== "string" ||
        !SIGNATURE_RE.test(signature) ||
        typeof message !== "string" ||
        message.length === 0 ||
        message.length > MAX_MESSAGE_LENGTH
      ) {
        return json({ error: "invalid address, message, or signature" }, 400);
      }

      const result = await verifySignature(
        address as `0x${string}`,
        message,
        signature as `0x${string}`
      );
      return json(result);
    }

    return env.ASSETS.fetch(request);
  },
};
