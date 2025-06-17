# Digital Electronic Systems Design - Laboratory Projects

[![Politecnico di Milano](https://img.shields.io/badge/University-Politecnico%20di%20Milano-blue)](https://www.polimi.it/)
[![Academic Year](https://img.shields.io/badge/Academic%20Year-2024%2F2025-green)](https://github.com/SimoneMessina0/DESD-Labs)
[![VHDL](https://img.shields.io/badge/Language-VHDL-orange)](https://github.com/SimoneMessina0/DESD-Labs)

This repository contains the complete implementation of Laboratory 2 and Laboratory 3 assignments for the **Digital Electronic Systems Design** course at Politecnico di Milano. The projects demonstrate advanced FPGA design concepts including image processing, audio signal processing, and real-time system control.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Laboratory 2: Image Processing System](#laboratory-2-image-processing-system)
- [Laboratory 3: Audio Processing System](#laboratory-3-audio-processing-system)
- [Team Members](#team-members)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Technologies Used](#technologies-used)
- [Documentation](#documentation)

## 🎯 Project Overview

These laboratory projects focus on implementing complex digital systems using VHDL for FPGA platforms. The assignments cover:

- **Lab 2**: Real-time image processing pipeline with color space conversion and convolution operations
- **Lab 3**: Advanced audio processing system with multiple effects and real-time control interfaces

## 🖼️ Laboratory 2: Image Processing System

### System Architecture
The image processing system implements a complete pipeline for real-time image manipulation, featuring:

- **Color Space Conversion**: RGB to Grayscale transformation
- **Image Convolution**: Configurable convolution filters for edge detection and image enhancement
- **Memory Management**: Efficient BRAM-based buffer management for high-throughput processing
- **Data Communication**: Robust packetizer/depacketizer modules for data streaming

### Key Modules
- `rgb2gray` - RGB to grayscale color space converter
- `img_conv` - Configurable 2D convolution engine
- `div3` - Hardware division by 3 implementation
- `BRAM_WRITER` - Block RAM interface controller
- `packetizer/depacketizer` - Data streaming protocol handlers
- `led_blinker` - Status indication system

## 🎵 Laboratory 3: Audio Processing System

### System Features
A comprehensive audio processing platform with real-time effects and user control:

- **Multi-Effect Audio Processing**: Configurable audio effects chain
- **Real-Time Control**: Joystick-based parameter adjustment
- **Volume Management**: Advanced volume control with saturation protection
- **Balance Control**: Stereo balance adjustment
- **Visual Feedback**: LED-based audio level visualization

### Key Modules
- `volume_controller` - Master volume control system
- `volume_multiplier` - High-precision audio multiplication
- `volume_saturator` - Audio clipping protection
- `balance_controller` - Stereo balance management
- `all_pass_filter` - Phase-shift audio filter
- `moving_average_filter` - Smoothing filter implementation
- `LFO` - Low Frequency Oscillator for modulation effects
- `effect_selector` - Dynamic effect chain management
- `diligent_jstk2` - Joystick interface controller
- `led_level_controller` - Audio level visualization
- `mute_controller` - Audio muting functionality

## 👥 Team Members

| Name | Lab 2 Contributions | Lab 3 Contributions |
|------|-------------------|-------------------|
| **Lucilla Bernardini** | BRAM_WRITER | volume_controller, volume_multiplier, volume_saturator, balance_controller |
| **Alessandro Lazzaroni** | depacketizer, packetizer | diligent_jstk2, led_level_controller |
| **Simone Francesco Messina** | div3, rgb2gray, img_conv, led_blinker | all_pass_filter, effect_selector, LFO, moving_average_filter_en, moving_average_filter, mute_controller |
| **Beatrice Rizzo** | - | led_controller |

## 🛠️ Technologies Used

- **Hardware Description Language**: VHDL
- **FPGA Platform**: Basys3 (Xilinx 7-Series FPGA)
- **Development Environment**: Xilinx Vivado Design Suite

## 🎓 Course Information

**Course**: Digital Electronic Systems Design  
**Institution**: Politecnico di Milano  
**Academic Year**: 2024/2025  
**Instructors**: [Nicola Lusardi, Andrea Costa, Gabriele Bonanno, Enrico Ronconi, Gabriele Fiumicelli]

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

*Developed for educational purposes as part of the Digital Electronic Systems Design course at Politecnico di Milano.*

---

*For questions about this project, please contact any of the team members listed above.*


