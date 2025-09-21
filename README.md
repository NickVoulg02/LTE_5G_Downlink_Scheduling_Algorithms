# 📡 LTE/5G Downlink Scheduling Algorithms in MATLAB

[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b-blue)](https://www.mathworks.com/products/matlab.html)
[![5G Toolbox](https://img.shields.io/badge/Toolbox-5G%20Toolbox-orange)](https://www.mathworks.com/products/5g.html)

Implementation and evaluation of **LTE/5G downlink scheduling algorithms** using MATLAB and the 5G Toolbox.  
The project explores trade-offs between **throughput** and **fairness** under different network conditions, schedulers, and traffic models.

---

## ✨ Implemented Scheduling Algorithms
- **Round Robin (RR)** → Cyclic allocation, ensures fairness but may sacrifice throughput.  
- **Proportional Fair (PF)** → Balances fairness and throughput using historical averages.  
- **Exponential Proportional Fair (EXP-PF)** → Introduces an exponential weighting factor `β` to tune fairness vs efficiency.  
- **Maximum Carrier-to-Interference (Max C/I)** → Maximizes throughput by prioritizing UEs with the best channel quality.  
- **Packet Loss Ratio (PLR)** → Allocates resources based on packet losses, improving resilience in certain traffic scenarios.  

Each scheduler is implemented as a custom subclass of `nrScheduler`.

---

## ⚙️ Simulation Setup
- **Environment**: MATLAB R2024b + 5G Toolbox  
- **Topology**: single gNB (base station) with configurable number of UEs at random positions  
- **Channel Model**: 3GPP TR 38.901 Urban Macro (UMa)  
- **Traffic Models**:
  - *Full Buffer* – continuous worst-case load  
  - *FTP* – bursty traffic with Pareto-distributed file sizes  
  - *VoIP (experimental)* – real-time packets (not all schedulers performed well)  

---

## 📊 Performance Metrics
- **Average Throughput** – measures network efficiency in resource utilization  
- **Jain’s Fairness Index** – quantifies fairness of resource allocation among UEs (0–1 scale)  

Both metrics are computed for varying numbers of users and resource block groups (RBGs).

---

## 🚀 How to Run
Clone the repo:
```bash
git clone https://github.com/NickVoulg02/LTE_5G_Downlink_Scheduling_Algorithms.git
cd LTE_5G_Downlink_Scheduling_Algorithms
