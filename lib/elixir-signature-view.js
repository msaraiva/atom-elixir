const { markdownToHTML, convertCodeBlocksToAtomEditors } = require('./utils');

class ElixirSignatureView extends HTMLElement {

  createdCallback() {
    this.getModel();
    this.addEventListener('click', () => this.getModel().destroyOverlay(), false);

    this.container = document.createElement('div');
    this.appendChild(this.container);
  }

  initialize(model) {
    this.setModel(model);
    return this;
  }

  getModel() {
    return this.model;
  }

  setModel(model) {
    this.model = model;
  }

  setData(data) {
    const paramPosition = data.active_param;
    const pipeBefore = data.pipe_before;
    const signatures = data.signatures.filter(sig => sig.params.length > paramPosition);

    let signatureElements = this.container.querySelectorAll('.signature');

    // Create signature elements
    signatures.forEach((sig, i) => {
      if (i < signatureElements.length) {
        return;
      }
      const signatureElement = document.createElement('div');
      this.container.appendChild(signatureElement);
      signatureElement.outerHTML =
        `<div class="signature">
          <div class="signature-func"></div>
          <div class="signature-spec"><pre><code></code></pre></div>
          <div class="signature-doc"></div>
        </div>`;
    });

    // Remove unused signature elements
    for (let i = signatures.length; i < signatureElements.length; i += 1) {
      signatureElements[i].remove();
    }

    convertCodeBlocksToAtomEditors(this.container);

    signatureElements = this.container.querySelectorAll('.signature');

    // Update signature elements
    signatureElements.forEach((e, i) => {
      const signature = signatures[i];
      const params = signature.params.map((param, j) => {
        if (pipeBefore && j === 0) {
          return `<span class="pipe-subject-param">${param}</span>`;
        } else if (j === paramPosition) {
          return `<span class="current-param">${param}</span>`;
        } else {
          return `<span class="param">${param}</span>`;
        }
      });

      e.children[0].innerHTML = `<span class="func-name">${signature.name}</span>(${params.join(', ')})`;

      const specElement = e.querySelector('.signature-spec');
      if (signature.spec === '') {
        specElement.style.display = 'none';
      } else {
        specElement.style.display = 'block';
        specElement.children[0].getModel().setText(signature.spec);
      }

      const docElement = e.querySelector('.signature-doc');
      if (signature.documentation === '') {
        docElement.style.display = 'none';
      } else {
        docElement.style.display = 'block';
        docElement.innerHTML = markdownToHTML(` _ ${signature.documentation} _ `);
      }
    });
  }

  destroy() {
    this.remove();
  }
}

module.exports = document.registerElement('elixir-signature-view', { prototype: ElixirSignatureView.prototype });
