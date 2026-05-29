async function waitForLiveSocket(page) {
  await page.waitForFunction(
    () => window.liveSocket && window.liveSocket.isConnected && window.liveSocket.isConnected()
  );
}

module.exports = { waitForLiveSocket };
