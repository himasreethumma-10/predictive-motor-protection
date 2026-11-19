# Predictive Motor Protection System

## Overview

This project implements a digital motor-monitoring and protection controller in FPGA RTL. It samples digitized current, voltage, and temperature values, evaluates current risk and other fault conditions, adjusts or disables a PWM command, and records fault statistics. It also includes a fast-trip path and an inverse-time overload accumulator.

The sensor inputs are already digital values. This repository does **not** implement an ADC conversion interface, motor power stage, physical-unit conversion, or a certified safety system. `pwm_out` is a logical command signal, not proof that power to a physical motor is disconnected. Motor-connected use requires a suitable gate-driver shutdown path and independent hardware overcurrent protection.

The checked-in Vivado project identifies Vivado 2023.2 and FPGA part `xc7a100tcsg324-1`. The project team reports Nexys 4 DDR board bring-up, but no XDC constraints are checked in, so the pin assignments, clock definition, and I/O standards for that bring-up are not captured here.

## Protection features

- Four-sample moving-average current filtering, trend calculation, and three-sample-ahead risk prediction.
- Current threshold classification and adaptive PWM duty.
- **Fast trip:** compares raw sampled current against a high threshold, bypassing the moving average, with a short qualification counter.
- **Inverse-time overload protection:** accumulates a digital overload value while current is elevated and slowly decays it below the warning threshold.
- Current deglitching on the normal filtered-current path.
- Voltage-range, temperature/thermal, persistence, stall, and sensor diagnostics.
- Fault classification, logging, cooldown, qualified recovery, and lockout.

All thresholds are digital counts, not amperes, volts, or degrees. Their use with a real motor requires sensor calibration and engineering validation.

## Current protection paths

The top-level current signal splits into separate paths. The fast-trip detector uses the sampled current directly; the deglitcher feeds inverse-time protection and the normal moving-average/filter path.

```text
current_raw -> input register -> current_sample -> fast-trip detector -----+
                                             |                             |
                                             +-> deglitcher -> inverse-time +-> fault classifier
                                                        |                    |
                                                        +-> 4-sample filter -+-> risk and other checks
```

### Fast trip

`fast_trip_detector` defaults to a threshold of **3500 counts** and a qualification count of **2 clock cycles**. It compares `current_sample` directly, rather than waiting for the four-sample current average to settle. The fault is asserted after the qualification count is met and clears when the sampled current falls below the threshold. This is a low-latency digital path, but it is not instantaneous protection or a substitute for hardware overcurrent protection.

### Inverse-time overload

`inverse_time_protection` defaults to a warning threshold of **1800 counts** and an accumulator trip limit of **2000**. On each clock, when its deglitched current input is at or above the warning threshold, it adds `(current >> 4) + 1` to a 16-bit accumulator, saturating at 65535. Below the threshold, the accumulator decays by 2 counts per clock until it reaches zero. The fault output asserts when the accumulator reaches the configured trip limit.

This means larger current counts build the accumulator faster, while lower current lets it decay. It is a simple RTL overload accumulator—not a calibrated inverse-time relay curve, IEC curve, or validated motor thermal model. Its timing depends on the clock frequency and current waveform.

### Current deglitcher

`current_deglitcher` defaults to a jump limit of **1000 counts** and a glitch qualification setting of **2**. A sample whose absolute difference from the preceding raw sample exceeds the jump limit is held out of the deglitched output for that cycle. The deglitcher also produces `deglitch_fault` after repeated qualifying jumps, but the top-level currently leaves that output unconnected; it is not independently reported as a fault. The fast-trip path intentionally bypasses deglitching, so a sufficiently high raw sampled current can still trip promptly.

## Current thresholds and risk

The default thresholds in `current_comparator` and `risk_classifier` are:

| Threshold | Count | Meaning |
|---|---:|---|
| Warning | 1800 | Warning and above |
| Danger | 2400 | Danger and above |
| Critical | 3000 | Critical and above |
| Emergency current | 3600 | Emergency-current fault / FAULT risk |

The comparator uses filtered current and its threshold flags are cumulative. The risk classifier uses filtered and predicted current, selecting the highest applicable level:

| Risk | Encoded value | Condition |
|---|---:|---|
| SAFE | 0 | Both current and prediction below 1800 |
| WARNING | 1 | Either is at least 1800, neither is at least 2400 |
| DANGER | 2 | Either is at least 2400, neither is at least 3000 |
| CRITICAL | 3 | Either is at least 3000, neither is at least 3600 |
| FAULT | 4 | Either is at least 3600 |

The predictor estimates `predicted_current = current + (delta_i × 3)`, clamps the result to 0–4095, and uses a horizon of three samples. `delta_i` is a change in digital counts per sample, not per second.

## Other default checks

| Check | Default behavior |
|---|---|
| Sensor diagnostics | Invalid sensor input faults immediately; also checks stuck-at-zero/max readings and large jumps |
| Voltage | Fault below 1000 or above 4000 counts; the range endpoints are inclusive |
| Thermal | Fault at thermal state or measured temperature of 3000 counts or more |
| Thermal estimate | Adds 8 counts per clock when filtered current exceeds 1200; otherwise cools by 2 counts per clock; measured temperature is incorporated as a floor |
| Persistent overload | Danger/critical comparator condition sustained for 8 clocks |
| Stall | Filtered current >= 2400, PWM duty <= 300, and non-rising current for 8 clocks |
| Cooldown | 16 clock cycles |
| Self-check before recovery | Fault clear and risk no higher than WARNING for 8 consecutive cycles |
| Recovery | At most 3 automatic attempts after reset; PWM ramps by 10 counts per clock |

These are digital models and counters, not calibrated physical-unit or safety limits. The BIST checks the sensor-valid input during startup; it does not test the internal datapath, PWM hardware, or motor.

## Fault codes

When multiple fault conditions are active, the first matching condition wins:

| Priority | Code | Fault |
|---:|---:|---|
| 1 | 1 | Sensor fault |
| 2 | 2 | Fast trip, inverse-time overload, or emergency current |
| 3 | 3 | Thermal fault |
| 4 | 4 | Stall |
| 5 | 5 | Voltage fault |
| 6 | 6 | Persistent overload |
| — | 0 | No fault |

The code reports the highest-priority active fault, not every simultaneous fault. The deglitcher's `deglitch_fault` is currently not wired into this classifier.

## PWM and recovery behavior

Default risk-based duty targets are SAFE 800, WARNING 650, DANGER 450, CRITICAL 200, and FAULT 0. Duty is measured in counts of a 1024-count PWM period, so 800 is approximately 78.1%. Outside recovery, the duty target is selected directly; during recovery it increases by 10 counts per clock. Any classified fault or disabled FSM state forces `pwm_out` low.

After a trip, the controller disables the PWM command, waits through cooldown, then performs a clear-condition qualification. If the fault is absent, risk is SAFE or WARNING for 8 consecutive clocks, and an attempt remains, it enters recovery. A continuing fault, excessive risk, or exhausted attempts results in lockout. Lockout remains until reset. This is RTL control behavior, not a physical safety guarantee.

## Simulation and validation

The Vivado project uses `tb_motor_protection_top` as the simulation top. In the Vivado Tcl Console:

```tcl
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
```

If a simulation is already open, close it first with `close_sim`. A successful run prints:

```text
PASS: all motor protection testbench scenarios completed
```

The current testbench exercises startup/BIST, safe PWM duty, filtered emergency overcurrent and fault logging, recovery and attempt limits, invalid sensor shutdown, and startup BIST failure. It does **not** currently test the newly documented deglitcher, fast-trip qualification, inverse-time accumulation/decay, voltage limits, thermal thresholds, persistence and stall timing, PWM waveform period, or simultaneous-fault priority. Add dedicated tests before relying on those behaviors.

Project-team-reported results: behavioral simulation passed the documented scenarios; prior synthesis completed with 0 errors and 0 critical warnings, and implementation/routing reported 343 LUTs and 285 flip-flops on `xc7a100tcsg324-1`. These resource figures are from the source version before the thermal-state fix and have not been confirmed by a subsequent synthesis run. Timing closure has **not** been demonstrated: the reported WNS/TNS were NA because no user timing constraints were supplied. Board bring-up reports do not establish protection behavior with real sensor inputs or physical-motor validation.

## Relationship to the reference paper

The reference is A. Aib, D. E. Khodja, S. Chakroune, and H. Rahali, “Fuzzy current analysis-based fault diagnostic of induction motor using hardware co-simulation with field programmable gate array,” *Electrical Engineering & Electromechanics*, 2023, no. 6, pp. 3–9, [doi:10.20998/2074-272X.2023.6.01](https://doi.org/10.20998/2074-272X.2023.6.01). It studies fuzzy-logic diagnosis of phase unbalance and missing phase using stator-current RMS, validated with hardware co-simulation on a Xilinx ML402/Virtex-4 platform and MATLAB/Simulink System Generator.

This project does **not** reproduce that diagnostic method: it has one digital current channel, fixed thresholds and risk logic, and no fuzzy inference or phase-unbalance/missing-phase diagnosis. Its fast trip, inverse-time overload, PWM control, and recovery are distinct supervisory protection features. Matching the paper would require multi-phase current acquisition, RMS processing, fuzzy inference, and validation against the reference setup.

## File guide

| File | Purpose |
|---|---|
| `motor_protection_top.v` | Top-level wiring and external inputs/outputs |
| `adc_interface.v` | Registers incoming digital sensor values; not an ADC driver |
| `current_deglitcher` | Current jump filtering and deglitch indication |
| `fast_trip_detector` | Low-latency raw-current threshold and qualification |
| `inverse_time_protection` | Digital inverse-time overload accumulator |
| `current_filter.v` | Four-sample current moving average |
| `current_comparator.v` | Current warning, danger, critical, and emergency flags |
| `trend_detector.v`, `risk_predictor.v`, `risk_classifier.v` | Current trend and risk estimation |
| `voltage_power_monitor.v`, `thermal_estimator.v` | Voltage/power and thermal checks |
| `persistence_detector.v`, `stall_detector.v`, `sensor_diagnostics.v` | Additional fault checks |
| `fault_classifier.v`, `protection_fsm.v` | Fault priority and protection/recovery states |
| `adaptive_pwm.v`, `pwm_generator.v` | Risk-based PWM duty and PWM waveform |
| `fault_logger.v` | Last fault code, peak current, and fault duration |
| `tb_motor_protection_top.v` | Self-checking behavioral testbench |
| `Project_simulation_1.xpr` | Vivado project configuration |

## Before motor-connected validation

1. Calibrate sensor inputs and convert digital counts to physical units; set thresholds for the actual motor and sensors.
2. Add tests for fast-trip, deglitch, inverse-time accumulation and decay, voltage and thermal limits, persistence/stall timing, PWM timing, fault priority, and boundary cases.
3. Connect or otherwise handle `deglitch_fault` if it is intended to trigger a reported fault.
4. Add and verify the Nexys 4 DDR pin, clock, and I/O constraints used for board bring-up.
5. Validate with real sensor signals on a safe bench setup before connecting a motor. This prototype is not a substitute for independent hardware overcurrent protection or a certified safety system.
