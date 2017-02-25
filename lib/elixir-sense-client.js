var net = require('net');
require('./jem.js');

module.exports = class ElixirSenseClient {

  constructor(host, port, env, projectPath) {
    this.env = env;
    this.projectPath = projectPath;
    this.onResult = null;
    this.client = new net.Socket();
    this.client.connect(port, host, () => {
    	console.log(`[atom-elixir] ElixirSense client connected on ${host}:${port}`);
    });

    this.client.on('data', (data) => {
      try {
        var buffer = new ArrayBuffer(data.length);
        var view = new DataView(buffer);
        data.forEach((n, i) => view.setUint8(i, n));
        if (this.onResult) {
          const result = Inaka.Jem.decode(buffer)
          if (result)
            this.onResult(result);
        }
      } catch(e) {
        console.error(e);
      }
    });

    this.client.on('close', () => {
    	console.log('[atom-elixir] ElixirSense client connection closed');
    });

    this.client.on('error', function(err) {
       console.log('[atom-elixir] ' + err)
    })
  }

  write(data, onResult) {
    this.onResult = onResult;
    var encoded   = Inaka.Jem.encode(data)
    const header  = createHeader(encoded)
    const body    = new Buffer(encoded);
    const packet  = new Uint8Array(header.length + encoded.byteLength);
    packet.set(header, 0);
    packet.set(body, header.length);

    // console.log("packet", packet)
    this.client.write(new Buffer(packet));
  }

  setContext(env, cwd) {
    this.write({request: "set_context", payload: {env, cwd}}, result => {
      if (result[0] != this.env)
        this.env = result[0]
        console.log(`[atom-elixir] Environment changed to \"${this.env}\"`)
      if (result[1] != this.projectPath)
        console.log(`[atom-elixir] Working directory changed to \"${this.projectPath}\"`)
        this.projectPath = result[1];
    })
  }
}

function createHeader(encoded) {
  var dv = new DataView(new ArrayBuffer(5));
  dv.setUint8(0, 101);
  dv.setUint32(1, encoded.byteLength);
  return new Buffer(dv.buffer);
}
