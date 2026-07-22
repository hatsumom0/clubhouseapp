import { useEffect, useMemo, useRef, useState } from "react";
import {
  GlyphWalletProvider,
  useGlyph,
  useNativeGlyphConnection,
} from "@use-glyph/sdk-react";
import { useAccount, useDisconnect, useSignMessage } from "wagmi";

/**
 * BAYC Clubhouse ↔ Glyph auth bridge.
 *
 * Opened by the iOS app inside ASWebAuthenticationSession with:
 *   ?nonce=<random>&callback=baycclubhouse://glyph-auth
 *
 * Flow: real Glyph login (X / email / wallet, powered by Privy) → wallet
 * connected via wagmi → sign a membership-proof message → redirect to the
 * app's custom scheme with address + signature + message.
 */

const ALLOWED_CALLBACK_PREFIX = "baycclubhouse://";

function bridgeParams() {
  const params = new URLSearchParams(window.location.search);
  const nonce = params.get("nonce") ?? crypto.randomUUID();
  const rawCallback = params.get("callback") ?? "baycclubhouse://glyph-auth";
  // Never redirect anywhere except back into the Clubhouse app.
  const callback = rawCallback.startsWith(ALLOWED_CALLBACK_PREFIX)
    ? rawCallback
    : "baycclubhouse://glyph-auth";
  return { nonce, callback };
}

function proofMessage(address: string, nonce: string, issuedAt: string) {
  return [
    "BAYC Miami Clubhouse Membership Verification",
    "",
    `Wallet: ${address}`,
    `Nonce: ${nonce}`,
    `Issued At: ${issuedAt}`,
    "",
    "Sign this message to verify you own this wallet. This will not trigger a blockchain transaction or cost any gas.",
  ].join("\n");
}

function base64url(s: string) {
  return btoa(unescape(encodeURIComponent(s)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

type Phase = "idle" | "connecting" | "signing" | "done" | "error";

function Bridge() {
  const { nonce, callback } = useMemo(bridgeParams, []);
  const { connect } = useNativeGlyphConnection();
  const { user, authenticated } = useGlyph();
  const { address, status: accountStatus } = useAccount();
  const { signMessageAsync } = useSignMessage();
  const { disconnect } = useDisconnect();

  const [phase, setPhase] = useState<Phase>("idle");
  const [error, setError] = useState<string | null>(null);
  const startedRef = useRef(false);

  const returnToApp = (addr: string, signature: string, message: string) => {
    const q = new URLSearchParams({
      address: addr,
      signature,
      message: base64url(message),
      nonce,
    });
    setPhase("done");
    window.location.replace(`${callback}?${q.toString()}`);
  };

  const signAndReturn = async (addr: string) => {
    if (startedRef.current) return;
    startedRef.current = true;
    setPhase("signing");
    setError(null);
    const message = proofMessage(addr, nonce, new Date().toISOString());
    try {
      const signature = await signMessageAsync({ message });
      returnToApp(addr, signature, message);
    } catch (e) {
      startedRef.current = false;
      setPhase("error");
      setError(e instanceof Error ? e.message : "Signature request failed.");
    }
  };

  // Once Glyph has connected a wallet, immediately ask for the ownership proof.
  useEffect(() => {
    if (address && accountStatus === "connected" && phase === "idle") {
      void signAndReturn(address);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [address, accountStatus]);

  const onConnect = async () => {
    setPhase("connecting");
    setError(null);
    try {
      await connect();
      setPhase("idle"); // effect above takes over once wagmi reports connected
    } catch (e) {
      setPhase("error");
      setError(e instanceof Error ? e.message : "Glyph login failed.");
    }
  };

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        <div style={styles.logoRow}>
          <div style={styles.logoCircle}>🐵</div>
        </div>
        <h1 style={styles.title}>BAYC MIAMI</h1>
        <p style={styles.subtitle}>CLUBHOUSE</p>

        {!address && (
          <>
            <p style={styles.copy}>
              Sign in with Glyph to verify your BAYC or MAYC membership.
            </p>
            <button
              style={styles.button}
              disabled={phase === "connecting"}
              onClick={onConnect}
            >
              {phase === "connecting" ? "Opening Glyph…" : "Sign in with Glyph"}
            </button>
            <p style={styles.fine}>X, email or wallet · Powered by Glyph</p>
          </>
        )}

        {address && phase === "signing" && (
          <>
            <p style={styles.copy}>
              Connected as{" "}
              <span style={styles.mono}>
                {user?.name ?? `${address.slice(0, 6)}…${address.slice(-4)}`}
              </span>
            </p>
            <p style={styles.copy}>Confirm the signature request in Glyph…</p>
          </>
        )}

        {address && phase === "done" && (
          <p style={styles.copy}>Verified — returning to the Clubhouse app…</p>
        )}

        {phase === "error" && (
          <>
            <p style={{ ...styles.copy, color: "#ff8a80" }}>{error}</p>
            {address ? (
              <button style={styles.button} onClick={() => signAndReturn(address)}>
                Try signature again
              </button>
            ) : (
              <button style={styles.button} onClick={onConnect}>
                Try again
              </button>
            )}
            {address && (
              <button
                style={styles.linkButton}
                onClick={() => {
                  disconnect();
                  startedRef.current = false;
                  setPhase("idle");
                  setError(null);
                }}
              >
                Use a different account
              </button>
            )}
          </>
        )}

        {authenticated && !address && phase !== "error" && (
          <p style={styles.fine}>Finishing Glyph session…</p>
        )}
      </div>
    </div>
  );
}

export default function App() {
  return (
    <GlyphWalletProvider askForSignature={false}>
      <Bridge />
    </GlyphWalletProvider>
  );
}

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
    boxSizing: "border-box",
  },
  card: {
    width: "100%",
    maxWidth: 380,
    textAlign: "center",
    padding: "36px 28px",
    borderRadius: 28,
    background: "rgba(255,255,255,0.06)",
    border: "1px solid rgba(255,255,255,0.12)",
    backdropFilter: "blur(20px)",
    WebkitBackdropFilter: "blur(20px)",
  },
  logoRow: { display: "flex", justifyContent: "center", marginBottom: 16 },
  logoCircle: {
    width: 84,
    height: 84,
    borderRadius: "50%",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: 40,
    background: "rgba(255,255,255,0.08)",
    border: "1px solid rgba(255,255,255,0.15)",
    boxShadow: "0 10px 30px rgba(243,156,18,0.25)",
  },
  title: {
    margin: 0,
    fontSize: 26,
    fontWeight: 900,
    letterSpacing: 6,
  },
  subtitle: {
    margin: "4px 0 20px",
    fontSize: 14,
    fontWeight: 600,
    letterSpacing: 8,
    color: "rgba(255,255,255,0.65)",
  },
  copy: {
    fontSize: 15,
    lineHeight: 1.5,
    color: "rgba(255,255,255,0.75)",
  },
  mono: {
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
    color: "#f39c12",
  },
  button: {
    width: "100%",
    marginTop: 16,
    padding: "16px 20px",
    fontSize: 16,
    fontWeight: 700,
    color: "#fff",
    background: "linear-gradient(135deg, #8b5cf6, #6d28d9)",
    border: "none",
    borderRadius: 18,
    cursor: "pointer",
    boxShadow: "0 8px 24px rgba(139,92,246,0.4)",
  },
  linkButton: {
    marginTop: 14,
    padding: 8,
    fontSize: 13,
    color: "rgba(255,255,255,0.55)",
    background: "none",
    border: "none",
    cursor: "pointer",
    textDecoration: "underline",
  },
  fine: {
    marginTop: 14,
    fontSize: 12,
    color: "rgba(255,255,255,0.45)",
  },
};
