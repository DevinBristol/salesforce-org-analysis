/**
 * Simple logger utility
 */

export function createLogger(name) {
  const timestamp = () => new Date().toISOString();

  return {
    info: (msg) => console.log(`[${timestamp()}] [${name}] INFO: ${msg}`),
    warn: (msg) => console.warn(`[${timestamp()}] [${name}] WARN: ${msg}`),
    error: (msg) => console.error(`[${timestamp()}] [${name}] ERROR: ${msg}`),
    debug: (msg) => {
      if (process.env.DEBUG) {
        console.log(`[${timestamp()}] [${name}] DEBUG: ${msg}`);
      }
    }
  };
}

export default { createLogger };
