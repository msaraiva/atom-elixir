var net = require('net');
require('./jem.js');

module.exports = class ElixirSenseClient {

  constructor(port) {
    this.onResult = null;
    this.client = new net.Socket();
    this.client.connect(port, 'localhost', () => {
    	console.log(`ElixirSense client connected on port ${port}`);
    	// TODO: this.client.send("set_env", env);
    });

    this.client.on('data', (data) => {
      try {
        var buffer = new ArrayBuffer(data.length);
        var view = new DataView(buffer);
        data.forEach((n, i) => view.setUint8(i, n));
        if (this.onResult) {
          const result = Inaka.Jem.decode(buffer)
          if (result !== null)
            this.onResult(result);
        }
      } catch(e) {
        console.error(e);
      }
    });

    this.client.on('close', () => {
    	console.log('ElixirSense client connection closed');
    });

    this.client.on('error', function(err) {
       console.log(err)
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
}

function createHeader(encoded) {
  var dv = new DataView(new ArrayBuffer(5));
  dv.setUint8(0, 101);
  dv.setUint32(1, encoded.byteLength);
  return new Buffer(dv.buffer);
}
