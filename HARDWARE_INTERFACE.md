# Gas Flow Control Hardware Interface

## Purpose

This document defines the hardware interface between the Raspberry Pi Gas
Controller software and the physical gas-control hardware.

The goal is to allow the application, backend, and Raspberry Pi controller
API to remain unchanged when simulated valve hardware is replaced with real
motorized needle valves, motor drivers, and sensors.

---

## System Architecture

The current system architecture is:

Flutter Application
    ↓
Main FastAPI Backend
    ↓
RemotePiHardware
    ↓
Network
    ↓
Raspberry Pi 4B
    ↓
Gas Controller API
    ↓
Valve Hardware Interface
    ↓
SimulatedValveHardware

The future physical architecture will be:

Flutter Application
    ↓
Main FastAPI Backend
    ↓
RemotePiHardware
    ↓
Network
    ↓
Raspberry Pi 4B
    ↓
Gas Controller API
    ↓
Valve Hardware Interface
    ↓
Physical Valve Hardware Driver
    ↓
Motor Driver
    ↓
Motorized Needle Valve
    ↓
Sensors / Position Feedback

---

## Current Controller

Controller hostname:

GasControlPi

The Raspberry Pi controller API currently runs on:

Port 9000

The controller service is managed by systemd:

gas-controller.service

The service is configured to start automatically when the Raspberry Pi boots.

---

## Valve Hardware Interface

Every physical valve implementation must provide the following operations.

### Read Valve State

Input:

tool_id

Required output:

- requested valve position
- actual valve position
- measured gas flow
- connection state
- fault state
- timestamp

---

### Set Valve Position

Operation:

set_position(tool_id, requested_percent)

Valid command range:

0% to 100%

The hardware layer must:

1. Validate the requested position.
2. Send the appropriate command to the motor driver.
3. Record the requested position.
4. Allow actual valve position to be independently measured or determined.
5. Report any hardware fault.
6. Update telemetry.

The requested position and actual position must remain separate values.

A command must not automatically be considered successful simply because it
was transmitted to the motor driver.

---

### Read Actual Valve Position

Operation:

read_position(tool_id)

Required output:

0% to 100%

The actual valve position should eventually come from real position feedback
or another validated position-determination method.

The application must not assume that:

requested position = actual position

---

### Close Valve

Operation:

close(tool_id)

The close command must command the valve toward its defined fully closed
position.

Expected requested position:

0%

The controller must continue monitoring actual position until the physical
valve reaches its closed state or a fault/timeout condition occurs.

---

### Close All Valves

Operation:

close_all()

Every configured valve must receive a close command.

Failure of one valve must not prevent the controller from attempting to close
the remaining valves.

Any individual failure must be reported.

---

## Flow Measurement

Future hardware should provide:

read_flow(tool_id)

Required unit:

CFH — cubic feet per hour

Required telemetry field:

measured_flow_cfh

The measured value must come from a physical flow sensor once the system moves
beyond simulation.

Flow limits are represented by:

- target_flow_cfh
- minimum_flow_cfh
- maximum_flow_cfh

The application already evaluates these values to determine whether flow is
within the configured operating range.

---

## Pressure Measurement

Future hardware should provide:

read_pressure(tool_id)

Required unit:

PSI

Required telemetry field:

cylinder_pressure_psi

Pressure values must ultimately come from an appropriate physical pressure
sensor.

Current pressure-warning thresholds in the application are development/demo
values only.

Production alarm thresholds must be defined from actual welding-process,
regulator, gas-system, and safety requirements before field deployment.

---

## Controller States

The system currently supports the following operational states.

### NORMAL

Conditions:

- controller connected
- no hardware fault
- valve at commanded position
- monitored flow within configured range
- no active pressure warning

---

### ADJUSTING

Used while the physical valve is moving toward its commanded position.

Example:

Requested: 50%
Actual: 27%

Normal valve travel must not automatically be treated as a hardware fault.

---

### WARNING

Used when the system remains operational but requires operator attention.

Examples:

- gas flow below configured minimum
- gas flow above configured maximum
- low cylinder pressure
- valve unable to reach commanded position within an eventually defined
  settling period

---

### FAULT

Used when the controller detects a hardware condition that prevents reliable
operation.

Future examples may include:

- motor-driver fault
- actuator stall
- position sensor failure
- invalid sensor reading
- hardware initialization failure
- valve movement timeout

---

### OFFLINE

Used when communication with the controller is unavailable.

When the Raspberry Pi controller becomes unreachable:

- the application remains running
- connection loss is displayed
- remote valve commands are disabled

When communication returns, the application should automatically recover.

This behavior has been tested using the Raspberry Pi controller architecture.

---

## Motor Driver Requirements

The final motor driver has not yet been selected.

Before implementing physical motor control, the selected driver must be
documented for:

- supply voltage
- motor voltage/current requirements
- command interface
- direction control
- position-control method
- enable/disable behavior
- fault output
- emergency/fail-safe behavior
- Raspberry Pi electrical interface requirements
- isolation requirements

The Raspberry Pi GPIO pins must not be connected directly to hardware that
exceeds Raspberry Pi electrical limits.

Any required signal conditioning, isolation, DAC, motor-driver interface, or
industrial I/O hardware must be identified before physical connection.

---

## Motorized Needle Valve Requirements

The final motorized needle valve has not yet been selected.

Before purchase or installation, confirm:

- compatible gas/service
- regulated inlet pressure
- outlet pressure requirements
- required CFH range
- valve flow coefficient / usable control range
- motor/actuator type
- compatible motor driver
- position-feedback capability
- power requirements
- materials compatibility
- maximum working pressure
- normally open / normally closed behavior if applicable
- defined safe state on loss of power

The valve must be selected from actual process requirements rather than from
software assumptions.

---

## Fail-Safe Design

Software controls do not replace physical gas-system safety devices.

The final system must define behavior for:

- application disconnect
- backend disconnect
- network failure
- Raspberry Pi failure
- Raspberry Pi power loss
- motor-driver power loss
- actuator stall
- sensor failure
- emergency shutdown
- loss of position feedback

A physical emergency stop and/or manual gas shutoff must remain independent of
the software application where required by the final system design.

The desired physical fail-safe valve state must be established before field
deployment.

---

## Current Development Implementation

The Raspberry Pi currently uses:

SimulatedValveHardware

This implementation:

- accepts valve commands
- tracks requested valve position
- simulates actual valve position
- simulates gas flow
- exposes telemetry through the controller API

It does not currently operate physical gas-control hardware.

---

## Future Physical Implementation

A future physical implementation may be named:

EnfieldValveHardware

or another hardware-specific implementation after the final valve and motor
driver are selected.

The physical implementation should replace SimulatedValveHardware without
requiring changes to:

- Flutter UI
- Flutter GasService
- main FastAPI API
- RemotePiHardware network interface
- Raspberry Pi controller API routes

This separation is intentional and is a core design requirement of the
system.

---

## Hardware Information Still Required

Before physical valve integration begins, determine:

1. Welding gas or gas mixtures used.
2. Regulated pressure entering the control valve.
3. Required minimum and maximum gas flow in CFH.
4. Selected motorized needle valve.
5. Selected motor driver.
6. Valve position-feedback method.
7. Selected flow sensor.
8. Selected pressure sensor.
9. Electrical power requirements.
10. Required physical fail-safe behavior.

Once these values are known, the physical valve hardware implementation can
be designed and tested.