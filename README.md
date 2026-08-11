# SYSTOLIC_ARRAY_DESIGN

This repository contains the **SystemVerilog RTL design of a 4×4 Systolic Array** for matrix multiplication.

The design consists of four main modules:

### 1. Processing Element (PE)

A Processing Element performs a **dual-stage pipelined Multiply-Accumulate (MAC) operation**. It receives activation and weight data, performs the computation, and passes the required data to the neighboring PE.

### 2. Matrix Feeder

The Matrix Feeder accepts **streaming activation and weight values** and organizes them into the appropriate dataflow required by the systolic array.

### 3. Systolic Array Computation

This module instantiates **16 Processing Elements (4×4)** and connects them to form the complete systolic array architecture.

### 4. Top Module

The top-level module instantiates and connects the **Matrix Feeder** and **Systolic Array Computation** modules, providing the overall interface for the design.

## Architecture

```text
                 Weights
                    ↓
        ┌────┬────┬────┬────┐
        │ PE │ PE │ PE │ PE │
        ├────┼────┼────┼────┤
Input → │ PE │ PE │ PE │ PE │ → Results
        ├────┼────┼────┼────┤
Input → │ PE │ PE │ PE │ PE │ → Results
        ├────┼────┼────┼────┤
Input → │ PE │ PE │ PE │ PE │ → Results
        └────┴────┴────┴────┘
                    ↓
                 Results
```

## Key Features

* 4×4 Systolic Array
* 16 Processing Elements
* Dual-stage pipelined MAC operation
* Streaming activation and weight inputs
* Pipelined data propagation
* Modular SystemVerilog RTL design
* Parallel matrix computation

## Applications

Systolic array architectures are commonly used in **AI/ML accelerators** for computationally intensive operations such as:

* Matrix Multiplication
* Convolution
* Neural Network acceleration
* Tensor operations
* AI accelerator architectures

## Technologies Used

* **SystemVerilog**
* RTL Design
* Pipelined MAC Architecture
* Systolic Array Architecture
* Matrix Multiplication
