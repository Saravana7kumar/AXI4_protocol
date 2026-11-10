# AXI4 Full Slave in Verilog

I built UART, SPI, FIFO, APB, AHB-Lite and AXI4-Lite before this. AXI4 Full is the next step up, and the main thing I wanted to understand is how it handles several transactions in flight at once without mixing up data or ordering.

This repo is a memory-mapped AXI4 slave written from scratch in Verilog, with a testbench that checks every transfer on its own.

## What it supports

- All five channels: AW, W, B, AR, R
- VALID/READY handshake on every channel
- FIXED, INCR and WRAP bursts
- Burst lengths up to 256 beats on INCR
- Transaction IDs on reads and writes
- Backpressure on every channel
- Multiple outstanding transactions, set by a parameter

## How outstanding transactions work here

Requests from AW and AR go into small FIFOs. The write and read engines pull from those FIFOs, so the master can keep issuing addresses while earlier bursts are still being served. The FIFO depth decides how many can be in flight.

Ordering follows the AXI4 rules:

- Same ID stays in order
- Different IDs may finish in any order
- AXI4 has no WID, so write data follows the AW order exactly
- Reads and writes have no ordering between them

The first version of the slave is in-order. Out-of-order read responses and read interleaving come after that.

## Folder layout

```
rtl/
  sync_fifo.v
  axi_addr_gen.v
  axi_write_ctrl.v
  axi_read_ctrl.v
  axi_mem.v
  axi_full_slave.v
  axi_full_top.v
tb/
  axi_master_bfm.v
  axi_scoreboard.v
  axi_protocol_checker.v
  axi_full_tb.v
```

## Verification

The testbench has a simple master model that can issue bursts with any ID, size, length and burst type. A scoreboard keeps the expected data per ID and compares it against what comes back. A protocol checker watches every channel and flags:

- payload changing while VALID is high and READY is low
- VALID dropping before the handshake finishes
- WLAST or RLAST in the wrong beat
- a burst crossing a 4KB boundary
- an illegal WRAP length or unaligned WRAP start

Tests run with random READY stalls and random burst settings across multiple seeds.

## Status

- [ ] Address generator (FIXED, INCR, WRAP)
- [ ] Single-beat write and read
- [ ] INCR bursts
- [ ] FIXED and WRAP bursts
- [ ] FIFO-based outstanding requests
- [ ] Backpressure tests
- [ ] Multi-ID tests
- [ ] Out-of-order and interleaved reads
- [ ] Scoreboard and protocol checker
- [ ] Random regression

## What I'm learning from this

- Why AXI splits address, data and response into separate channels
- How the 4KB rule shapes the burst logic
- Why WRAP bursts need an aligned start
- How much of the work is verification, not the RTL itself

## Related projects

- AXI4-Lite slave
- AHB-Lite slave
- APB
- SPI

## Author

Saravana Kumar K

