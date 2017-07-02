const spawn = require('child_process').spawn;
const path = require('path');

module.exports = class ServerProcess {

  constructor(projectPath, onTCPServerReady) {
    this.ready = false;
    this.testing = false;
    this.proc = null;

    this.projectPath = projectPath;
    this.command = 'elixir';
    this.args = [path.join(__dirname, 'elixir_sense/run.exs')];
    this.onTCPServerReady = onTCPServerReady;
  }

  start(port, env) {
    this.proc = this.spawnChildProcess(port, env);

    this.proc.stdout.on('data', (chunk) => {
      if (this.onTCPServerReady) {
        if (chunk.indexOf('ok:') !== -1) {
          const [, host, newPort, authToken] = chunk.toString().split(':');
          this.onTCPServerReady(host, newPort.trim(), authToken);
        }
        this.onTCPServerReady = null;
        return;
      }

      console.log(`[ElixirSense] ${chunk.toString()}`);
      this.ready = true;
    });

    this.proc.stderr.on('data', (chunk) => {
      this.ready = true;
      const message = `[ElixirSense] ${chunk.toString()}`;
      if (chunk.indexOf('Server Error') !== -1) {
        console.warn(message);
      } else {
        console.log(message);
      }
    });

    this.proc.on('close', (exitCode) => {
      console.log(`[atom-elixir] Child process exited with code ${exitCode}`);
      this.ready = false;
      this.proc = null;
    });

    this.proc.on('error', (error) => {
      console.error(`[atom-elixir] ${error.toString()}`);
      this.ready = false;
      this.proc = null;
    });
  }

  stop() {
    this.proc.stdin.end();
    this.ready = false;
    this.proc = null;
  }

  spawnChildProcess(port, env) {
    const options = {
      cwd: this.projectPath,
      stdio: 'pipe',
    };

    if (process.platform === 'win32') {
      options.windowsVerbatimArguments = true;
      const command = [this.command].concat(this.args).concat('tcpip', port, env).join(' ');
      return spawn('cmd', ['/s', '/c', `"${command}"`], options);
    } else {
      return spawn(this.command, this.args.concat('unix', port, env), options);
    }
  }
};
