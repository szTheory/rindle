(() => {
  const Uploaders = {};

  Uploaders.RindleTus = function (entries, onViewError) {
    entries.forEach((entry) => {
      const upload = new tus.Upload(entry.file, {
        endpoint: entry.meta.endpoint,
        uploadUrl: entry.meta.upload_url,
        metadata: {
          filename: entry.file.name,
          filetype: entry.file.type,
        },
        retryDelays: [0, 1000, 3000, 5000],
        removeFingerprintOnSuccess: true,
        onError: (error) => entry.error(error.message),
        onProgress: (bytesUploaded, bytesTotal) => {
          const pct = Math.floor((bytesUploaded / bytesTotal) * 100);
          if (pct < 100) entry.progress(pct);
        },
        onSuccess: () => entry.progress(100),
      });

      onViewError(() => upload.abort());

      upload.findPreviousUploads().then((previousUploads) => {
        if (previousUploads.length > 0) {
          upload.resumeFromPreviousUpload(previousUploads[0]);
        }

        upload.start();
      });
    });
  };

  const PresignedPut = {
    mounted() {
      this.pendingFile = null;

      this.handleEvent("presigned", ({ url, session_id, content_type }) => {
        const file =
          this.pendingFile || (this.el.files && this.el.files[0]);

        if (!file) {
          this.pushEvent("upload_failed", { message: "no file selected" });
          return;
        }

        fetch(url, {
          method: "PUT",
          body: file,
          headers: {
            "Content-Type": content_type || file.type || "application/octet-stream",
          },
        })
          .then((response) => {
            if (!response.ok) {
              throw new Error(`presigned PUT failed with ${response.status}`);
            }

            this.pendingFile = null;
            this.pushEvent("verify", { session_id });
          })
          .catch((error) => {
            console.error("PresignedPut failed", error);
            this.pushEvent("upload_failed", { message: error.message });
          });
      });

      this.el.addEventListener("change", () => {
        const file = this.el.files && this.el.files[0];
        if (!file) return;

        this.pendingFile = file;

        this.pushEvent("presign", {
          filename: file.name,
          content_type: file.type || "image/png",
        });
      });
    },
  };

  const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

  const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { PresignedPut },
    uploaders: Uploaders,
  });

  liveSocket.connect();
  window.liveSocket = liveSocket;

  document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
    el.addEventListener("click", () => {
      el.setAttribute("hidden", "");
    });
  });
})();
