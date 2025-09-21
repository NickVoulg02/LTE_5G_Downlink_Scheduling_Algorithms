# 📡 LTE/5G Downlink Scheduling Algorithms in MATLAB

[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b-blue)](https://www.mathworks.com/products/matlab.html)
[![5G Toolbox](https://img.shields.io/badge/Toolbox-5G%20Toolbox-orange)](https://www.mathworks.com/products/5g.html)

Implementation and evaluation of **LTE/5G downlink scheduling algorithms** using MATLAB and the 5G Toolbox.  
The project explores trade-offs between **throughput** and **fairness** across different schedulers and traffic models.

---

## ✨ Features
- ✅ Round Robin (RR)  
- ✅ Proportional Fair (PF)  
- ✅ Exponential Proportional Fair (EXP-PF, configurable β)  
- ✅ Maximum Carrier-to-Interference (Max C/I)  
- ✅ Packet Loss Ratio (PLR)  

Each scheduler is implemented as a custom `nrScheduler` class.

---

## ⚙️ Setup
- MATLAB **R2024b**  
- [5G Toolbox](https://www.mathworks.com/help/5g/)  

Clone the repo:
```bash
git clone https://github.com/NickVoulg02/LTE_5G_Downlink_Scheduling_Algorithms.git
cd LTE_5G_Downlink_Scheduling_Algorithms
