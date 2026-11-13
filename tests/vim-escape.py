#!/usr/bin/env python3
"""Check real terminal Escape input, including Kitty's startup negotiation."""

import os
from pathlib import Path
import select
import subprocess
import tempfile
import time


vimrc = Path(__file__).resolve().parents[1] / '.vimrc'
for terminal, escape in [('xterm-256color', b'\x1b'), ('xterm-kitty', b'\x1b[27u')]:
    with tempfile.TemporaryDirectory() as temporary:
        report = Path(temporary) / 'highlight'
        main_fd, child_fd = os.openpty()
        process = subprocess.Popen(
            ['vim', '-Nu', str(vimrc), '-i', 'NONE', '-n',
             '+call setline(1, ["needle", "another needle"])'],
            stdin=child_fd, stdout=child_fd, stderr=child_fd,
            env=dict(os.environ, TERM=terminal, REPORT=str(report)),
        )
        os.close(child_fd)
        output = b''

        def drain(duration):
            global output
            deadline = time.monotonic() + duration
            while time.monotonic() < deadline:
                if not select.select([main_fd], [], [], max(0, deadline - time.monotonic()))[0]:
                    return
                try:
                    data = os.read(main_fd, 65536)
                except OSError:
                    return
                if not data:
                    return
                output += data
                for query, reply in [(b'\x1b[?u', b'\x1b[?1u'),
                                     (b'\x1b[>c', b'\x1b[>1;4000;0c')]:
                    if query in output:
                        os.write(main_fd, reply)
                        output = output.replace(query, b'')

        def record():
            os.write(main_fd, b':call writefile([string(v:hlsearch), string(&hlsearch)], $REPORT, "a")\r')
            drain(0.1)

        try:
            drain(0.4)
            os.write(main_fd, b'/needle\r')
            drain(0.1)
            record()
            os.write(main_fd, escape)
            drain(0.2)
            record()
            os.write(main_fd, b'n')
            drain(0.1)
            record()
            os.write(main_fd, b':noh\r')
            drain(0.1)
            record()
            os.write(main_fd, b':qa!\r')
            drain(0.1)
            process.wait(timeout=3)
            assert process.returncode == 0, (terminal, output)
            # Escape matches :noh, keeps hlsearch enabled, and allows n to resume it.
            assert report.read_text().splitlines() == ['1', '1', '0', '1', '1', '1', '0', '1'], terminal
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(main_fd)

print('Normal and Kitty terminal Escape checks passed.')
