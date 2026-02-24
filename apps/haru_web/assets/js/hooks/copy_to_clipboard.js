const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const targetId = this.el.dataset.target;
      const target = document.getElementById(targetId);

      if (!target) return;

      navigator.clipboard.writeText(target.innerText).then(() => {
        const original = this.el.innerText;
        this.el.innerText = "Copied!";
        this.el.classList.add("bg-status-success");

        if (this.el.dataset.notify) {
          this.pushEvent(this.el.dataset.notify, {});
        }

        setTimeout(() => {
          this.el.innerText = original;
          this.el.classList.remove("bg-status-success");
        }, 2000);
      });
    });
  },
};

export default CopyToClipboard;
