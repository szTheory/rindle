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

  const MULTIPART_PART_SIZE = 5 * 1024 * 1024;

  function putPresigned(url, body, contentType) {
    return fetch(url, {
      method: "PUT",
      body,
      headers: {
        "Content-Type": contentType || "application/octet-stream",
      },
    }).then((response) => {
      if (!response.ok) {
        throw new Error(`presigned PUT failed with ${response.status}`);
      }

      const etag = response.headers.get("etag");
      return etag ? etag.replaceAll('"', "") : null;
    });
  }

  function makePresignedHook(presignedEvent, verifyEvent, presignEvent) {
    return {
      mounted() {
        this.pendingFile = null;

        this.handleEvent(presignedEvent, ({ url, session_id, content_type }) => {
          const file = this.pendingFile || (this.el.files && this.el.files[0]);

          if (!file) {
            this.pushEvent("upload_failed", { message: "no file selected" });
            return;
          }

          putPresigned(url, file, content_type || file.type)
            .then(() => {
              this.pendingFile = null;
              this.pushEvent(verifyEvent, { session_id });
            })
            .catch((error) => {
              console.error(`${presignEvent} failed`, error);
              this.pushEvent("upload_failed", { message: error.message });
            });
        });

        this.el.addEventListener("change", () => {
          const file = this.el.files && this.el.files[0];
          if (!file) return;

          this.pendingFile = file;
          this.pushEvent(presignEvent, {
            filename: file.name,
            content_type: file.type || "application/octet-stream",
          });
        });
      },
    };
  }

  const PresignedPut = makePresignedHook("presigned", "verify", "presign");
  const PresignedVideoPut = makePresignedHook("presigned_video", "verify_video", "presign_video");
  const PresignedMuxPut = makePresignedHook("presigned_mux", "verify_mux", "presign_mux");

  const MultipartUpload = {
    mounted() {
      this.handleEvent("multipart_parts", async ({ session_id, parts }) => {
        try {
          const part1 = new Uint8Array(MULTIPART_PART_SIZE);
          part1.fill(97);
          const part2 = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);

          const bodies = [part1, part2];
          const etags = [];

          for (let i = 0; i < parts.length; i++) {
            const etag = await putPresigned(parts[i].url, bodies[i], "application/octet-stream");
            etags.push({ part_number: parts[i].part_number, etag });
          }

          this.pushEvent("multipart_complete", { session_id, etags });
        } catch (error) {
          console.error("MultipartUpload failed", error);
          this.pushEvent("upload_failed", { message: error.message });
        }
      });

      this.el.addEventListener("click", () => {
        this.pushEvent("multipart_start", { filename: "multipart-demo.bin" });
      });
    },
  };

  // Copy-to-clipboard for the launchpad access panel (URLs / credentials).
  const Copy = {
    mounted() {
      this.el.addEventListener("click", async () => {
        const text = this.el.dataset.copy || "";
        try {
          await navigator.clipboard.writeText(text);
        } catch (_e) {
          const ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          try {
            document.execCommand("copy");
          } finally {
            ta.remove();
          }
        }
        this.el.dataset.copied = "true";
        clearTimeout(this._copiedTimer);
        this._copiedTimer = setTimeout(() => {
          delete this.el.dataset.copied;
        }, 1200);
      });
    },
  };

  const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

  const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { PresignedPut, PresignedVideoPut, PresignedMuxPut, MultipartUpload, Copy },
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
