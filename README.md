# Gas Flow Control

**Current Software Release:** v1.2.0
**Status:** Software prototype complete; physical valve and sensor integration pending

## Live Application

**Gas Flow Control Web App:**
https://gas-flow-control-demo.web.app

The app can be opened in Safari and added to an iPhone Home Screen.

Demo Mode can operate without an Internet connection after the application has been initially loaded and cached.

---

## Project Overview

Gas Flow Control is a wireless control platform designed to support remote argon-flow management during welding operations.

The system is intended to allow authorized field personnel to monitor and control individual gas-control channels from a simple mobile/web interface.

The project currently supports six independent controller/tool positions and is structured so that the existing software can later be connected to physical proportional valves, pressure sensors, and flow sensors without redesigning the user interface.

---

## Current Capabilities

The current software release includes:

* Secure sign-in using employee email and 6-digit PIN
* Six independent controller/tool positions
* Remote valve-position commands
* Individual valve close
* Close All Valves
* Requested valve-position monitoring
* Actual valve-position architecture
* Gas-flow monitoring architecture
* Pressure monitoring architecture
* System status monitoring
* NORMAL, ADJUSTING, WARNING, FAULT, and OFFLINE states
* Command history
* Connection-loss detection
* Automatic recovery after controller communication returns
* Offline Demo Mode
* iPhone Home Screen installation
* Firebase web deployment
* Raspberry Pi 4 controller integration
* Raspberry Pi automatic controller startup
* Hardware abstraction for future physical valve control

---

## System Architecture

Current field-ready architecture:

iPhone / Browser
        |
        v
Local Wi-Fi
        |
        v
GasControlPi
   |           |
   |           |
   v           v
Main Backend   Gas Controller
Port 8000      Port 9000
   |              |
   +-------> remote_pi
                  |
                  v
        Valve Hardware Interface
                  |
                  v
        Future Physical Valve/Sensors


---

## Operating Modes

### Demo Mode

Demo Mode allows the interface to run without physical valve hardware.

It supports:

* Login
* Home screen
* Valve controls
* Individual valve close
* Close All
* Status behavior
* Command history
* Offline operation

Demo Mode does not control physical gas hardware.

### Controller Mode

Controller Mode is intended for communication with the Raspberry Pi over a local wireless network.

Internet access is not required for local controller communication once the final local deployment configuration is complete.

---

## Raspberry Pi Controller

Current Raspberry Pi hostname:

```text
GasControlPi
```

Controller API port:

```text
9000
```

Linux service:

```text
gas-controller.service
```

The controller is configured to start automatically when the Raspberry Pi boots.

Check controller status:

```bash
sudo systemctl status gas-controller
```

Expected result:

```text
Loaded: loaded (... enabled ...)
Active: active (running)
```

Controller health:

```powershell
Invoke-RestMethod http://PI_IP_ADDRESS:9000/health
```

Expected response includes:

```text
ok          : True
controller  : GasControlPi
hardware    : simulated-valve
tool_count  : 6
```

---

## Self-Contained Raspberry Pi Deployment

The Raspberry Pi now hosts both required backend services:

- `gas-backend.service` on port `8000`
- `gas-controller.service` on port `9000`

Both services are configured with `systemd` and start automatically when the Raspberry Pi boots.

The main backend runs in:

```text
remote_pi

---

## Repository Structure

```text
gas_flow_control/
|
|-- flutter_app/
|   |-- lib/
|   |-- web/
|   `-- build/
|
|-- pi_backend/
|
|-- pi_controller/
|   |-- controller.py
|   `-- valve_hardware.py
|
|-- docs/
|
|-- start_backend.ps1
|-- start_backend_remote_pi.ps1
|
`-- README.md
```

---

## Documentation

Project documentation is stored in:

```text
docs/
```

Recommended handoff documents include:

* Management Summary
* Installation Guide
* Operator Quick Guide
* Technical Handoff

These documents describe:

* Project purpose
* Estimated prototype cost
* Operator use
* Installation
* Raspberry Pi setup
* Future physical hardware integration

---

## Flutter Development

From the Flutter project directory:

```powershell
cd flutter_app
flutter pub get
flutter analyze
```

Expected result:

```text
No issues found!
```

Run locally in Demo Mode:

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=true --dart-define=OPERATOR_ID=field-review --dart-define=ACCESS_PIN=YOUR_PIN --dart-define=HARDER_EMAIL_DOMAIN=YOUR_DOMAIN
```

---

## Web Build

Build the offline-capable web application:

```powershell
flutter clean
flutter pub get
flutter analyze
```

Then:

```powershell
flutter build web --no-web-resources-cdn --dart-define=DEMO_MODE=true --dart-define=OPERATOR_ID=field-review --dart-define=ACCESS_PIN=YOUR_PIN --dart-define=HARDER_EMAIL_DOMAIN=YOUR_DOMAIN
```

---

## Firebase Deployment

From the project root:

```powershell
firebase.cmd deploy --only hosting
```

Current Firebase project:

```text
gas-flow-control-demo
```

Live application:

https://gas-flow-control-demo.web.app

---

## Version Control

Primary branch:

```text
master
```

Current release tag:

```text
v1.2.0
```

Before editing:

```powershell
git pull origin master
```

After approved changes:

```powershell
git add .
git commit -m "Describe change"
git push origin master
```

Check repository status:

```powershell
git status
```

Desired result:

```text
nothing to commit, working tree clean
```

---

## Recommended Physical Hardware Direction

The current preferred one-valve prototype architecture is:

```text
Raspberry Pi 4
        |
        v
Sequent Microsystems SM-I-001
Industrial Automation HAT
        |
        v
0-10 V Control Signal
        |
        v
Enfield PFV Proportional Valve
```

The recommended Enfield valve concept is a PFV proportional solenoid valve with:

* 24 VDC power
* 0-10 V command
* Normally closed operation
* Integrated linear driver
* Proportional flow control
* Stainless construction where appropriate

---

## Field Information Still Required

Before selecting the exact physical valve and sensors, confirm:

* Normal argon flow in CFH
* Minimum argon flow
* Maximum argon flow
* Regulated pressure entering the valve in PSI
* Existing regulator/flowmeter model
* Existing tubing/fitting size
* Installation environment
* Required power-loss behavior
* Manual gas-isolation requirements

These values determine the exact valve, sensor ranges, fittings, and enclosure requirements.

---

## Recommended Next Engineering Step

The next physical milestone should be a one-valve prototype.

First test:

```text
Gas Flow Control App
        |
        v
Raspberry Pi
        |
        v
Industrial 0-10 V I/O
        |
        v
Digital Multimeter
```

Verify:

* 0% = approximately 0.0 V
* 25% = approximately 2.5 V
* 50% = approximately 5.0 V
* 75% = approximately 7.5 V
* 100% = approximately 10.0 V

After successful electrical verification:

1. Connect one proportional valve.
2. Verify physical valve movement without gas.
3. Add pressure sensing.
4. Add argon flow sensing.
5. Calibrate.
6. Conduct controlled gas testing.
7. Begin field validation.

---

## Current Limitations

The software is complete enough for demonstration and future hardware integration.

The overall gas-control system is not yet production validated.

Still required before physical field deployment:

* Final valve selection
* Pressure sensor selection
* Flow sensor selection
* Electrical integration
* Calibration
* Gas compatibility verification
* Pressure-rating verification
* Controlled gas testing
* Fail-safe validation
* Field testing
* Engineering/safety review

---

## Project Handoff Status

The user interface should remain feature-frozen unless future testing identifies a specific operational need.

Future development should focus on:

* Physical valve control
* Sensor integration
* Calibration
* Local controller deployment
* Controlled gas testing
* Field validation

The existing architecture is designed so these hardware additions can be made without rewriting the completed user interface.
