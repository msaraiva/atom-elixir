const net = require('net');
require('./jem.js');

function createHeader(encoded) {
  const dataView = new DataView(new ArrayBuffer(4));
  dataView.setUint32(0, encoded.byteLength);
  return new Buffer(dataView.buffer);
}

function toErlString(buffer) {
  const dataView = new DataView(buffer);
  const a = [];
  for (let i = 0; i < dataView.byteLength; i += 1) {
    a[i] = dataView.getUint8(i);
  }
  return `<<${a.join(',')}>>`;
}

module.exports = class ElixirSenseClient {

  constructor(host, port, authToken, env, projectPath) {
    this.host = host;
    this.port = port;
    this.authToken = authToken ? authToken.trim() : null;
    this.projectPath = projectPath;
    this.env = env;

    this.client = new net.Socket();
    this.lastRequestId = 0;
    this.requests = {};

    this.packetSize = 0;
    this.packetPos = 0;
    this.packetBuffer = null;
    this.packetBufferView = null;

    this.initClient();
  }

  initClient() {
    this.client.connect(this.port, this.handleConnect.bind(this));
    this.client.on('data', this.handleData.bind(this));
    this.client.on('close', this.handleClose.bind(this));
    this.client.on('error', this.handleError.bind(this));
  }

  handleConnect() {
    this.resetBuffer(0, 4);
    console.log(`[atom-elixir] ElixirSense client connected on ${this.host}:${this.port}`);
  }

  handleClose() {
    console.log('[atom-elixir] ElixirSense client connection closed');
  }

  handleError(error) {
    console.log(`[atom-elixir] ${error}`);
  }

  handleData(data) {
    try {
      this.readPacket(data);
    } catch (e) {
      console.error(e);
      this.requests = {};
    }
  }

  readPacket(data) {
    let dataPos = 0;

    if (this.packetPos === 0) {
      dataPos = this.readSize(data, dataPos);
      const size = this.packetBufferView.getUint32(0);
      this.resetBuffer(0, size);
    }

    dataPos = this.readBody(data, dataPos);

    if (this.packetPos === this.packetSize) {
      // DEBUG
      let result = null;
      try {
        result = Inaka.Jem.decode(this.packetBuffer);
      } catch (error) {
        console.error(`[atom-elixir] Cannot decode Erlang term: ${toErlString(this.packetBuffer)}\nReason:`, error);
        this.resetBuffer(0, 4);
        return dataPos;
      }

      try {
        const onResult = this.requests[result.request_id];
        delete this.requests[result.request_id];
        if (onResult) {
          if (result.error) {
            console.error(`[atom-elixir] Server error: ${result.error}`);
          } else {
            onResult(result.payload);
          }
        } else {
          console.error('[atom-elixir] Server response contains invalid request id');
          this.requests = {};
        }
      } catch (error) {
        console.error('[atom-elixir]', error);
      }
      this.resetBuffer(0, 4);
    }

    return dataPos;
  }

  readSize(data, dataPos) {
    let pos = dataPos;
    while (pos < 4) {
      this.packetBufferView.setUint8(pos, data[pos]);
      pos += 1;
    }
    return pos;
  }

  readBody(data, dataPos) {
    let pos = dataPos;
    while (pos < data.length) {
      this.packetBufferView.setUint8(this.packetPos, data[pos]);
      this.packetPos += 1;
      pos += 1;
    }
    return pos;
  }

  resetBuffer(pos, size) {
    this.packetPos = pos;
    this.packetSize = size;
    this.packetBuffer = new ArrayBuffer(this.packetSize);
    this.packetBufferView = new DataView(this.packetBuffer);
  }

  write(data) {
    const encoded = Inaka.Jem.encode(data);
    const header = createHeader(encoded);
    const body = new Buffer(encoded);
    const packet = new Uint8Array(header.length + encoded.byteLength);
    packet.set(header, 0);
    packet.set(body, header.length);
    this.client.write(new Buffer(packet));
  }

  send(request, payload, onResult) {
    this.lastRequestId = this.lastRequestId + 1;
    this.requests[this.lastRequestId] = onResult;
    this.write({
      request_id: this.lastRequestId,
      auth_token: this.authToken,
      request,
      payload,
    });
  }

  setContext(env, cwd) {
    this.send('set_context', { env, cwd }, (result) => {
      if (result[0] !== this.env) {
        this.env = result[0];
        console.log(`[atom-elixir] Environment changed to "${this.env}"`);
      }
      if (result[1] !== this.projectPath) {
        this.projectPath = result[1];
        console.log(`[atom-elixir] Working directory changed to "${this.projectPath}"`);
      }
    });
  }
};
