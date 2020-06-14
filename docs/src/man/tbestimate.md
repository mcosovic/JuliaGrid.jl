# [State Estimation](@id stateestimation)
The state estimation is used for describing the present state of the power system, unlike the power flow analysis which is used for defining load profiles, generator capabilities, voltage specification, contingency analysis, and planning.
```@raw html
<img src="../../assets/ems.png" class="center"/>
<figcaption>Figure 1: The energy management system configuration and state estimation routines.</figcaption>
&nbsp;
```

The state estimation is a part of the energy management systems and typically includes network topology processors, observability analysis, state estimation algorithm and bad data analysis, as shown in Figure 1. Data for the state estimation arrives from SCADA (Supervisory Control and Data Acquisition) and WAMS (Wide Area Measurement System) technology. SCADA provides legacy measurements with low sampling rates insufficient to capture system dynamics in real-time and provides a snapshot state estimation with order of seconds and minutes latency. In contrast, WAMS provides data from PMUs with high sampling rates (10 ms - 20 ms) enabling the real-time system monitoring.

In a usual scenario, the state estimation model is described with the system of non-linear equations, where bus voltage magnitudes and bus voltage angles are state variables ``\mathbf{x}``. The core of the state estimation is the state estimation algorithm that provides an estimate of the system state ``\mathbf{x}`` based on the network topology and available measurements. State estimation is performed on a bus/branch model and used to reconstruct the state of the system. Conventional state estimation algorithms use the Gauss-Newton method to solve the non-linear weighted least-squares problem [[1, 2]](@ref refestimate). Besides the non-linear state estimation model, the DC model is obtained by linearization of the non-linear model, and it provides an approximate solution. The DC state estimate is obtained through non-iterative procedure by solving the linear weighted least-squares problem.

---

## Measurement Model
We refer the reader to section [Network Equations](@ref networkequationpage) which precedes the analysis given here. The state estimation algorithm estimates the values of the state variables based on the knowledge of network topology and parameters, and measured values obtained from measurement devices spread across the power system. The knowledge of the network topology and parameters is provided by the network topology processor in the form of the bus/branch model, where branches of the grid are usually described using the two-port ``\pi``-model [[3, Ch. 1,2]](@ref refestimate).

As an input, the state estimation requires a set of measurements ``\mathcal{M}`` of different electrical quantities spread across the power network. Using the bus/branch model and available measurements, the observability analysis defines observable and unobservable parts of the network, subsequently defining the additional set of pseudo-measurements needed to determine the solution [[3, Ch. 4]](@ref refestimate).
Finally, the measurement model can be described as the system of equations [[1]](@ref refestimate):  
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x})+\mathbf{u},
```
where ``\mathbf {x}=[x_1,\dots,x_{s}]^{T}`` is the vector of the state variables, ``\mathbf{h}(\mathbf{x})=`` ``[h_1(\mathbf{x})``, ``\dots``, ``h_k(\mathbf{x})]^{{T}}`` is the vector of measurement functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors. The state estimation problem in transmission grids is commonly an overdetermined system of equations ``(k>s)`` [[4, Sec. 2.1]](@ref refestimate).

Each measurement ``M_i \in \mathcal{M}`` is associated with measured value ``z_i``, measurement error ``u_i``, and measurement function ``h_i(\mathbf{x})``. Under the assumption that measurement errors ``u_i`` follow a zero-mean Gaussian distribution, the probability density function associated with the i-th measurement is proportional to:
```math
  \mathcal{N}(z_i|\mathbf{x},v_i) \propto \exp\Bigg\{\cfrac{[z_i-h_i(\mathbf{x})]^2}{2v_i}\Bigg\},
```
where ``v_i`` is the measurement variance defined by the measurement error ``u_i``, and the measurement function ``h_i(\mathbf{x})`` connects the vector of state variables ``\mathbf{x}`` to the value of the i-th measurement.

The state estimation in electric power systems deals with the problem of determining state variables ``\mathbf{x}`` according to the noisy observed data ``\mathbf{z}`` and a prior knowledge:
```math
 		p(\mathbf{x}|\mathbf{z})= \cfrac{p(\mathbf{z}|\mathbf{x})p(\mathbf{x})}{p(\mathbf{z})}.
```
Assuming that the prior probability distribution ``p(\mathbf{x})`` is uniform, and given that ``p(\mathbf{z})`` does not depend on ``\mathbf{x}``, the maximum a posteriori solution reduces to the maximum likelihood solution, as given below [[5]](@ref refestimate):
```math
	\hat{\mathbf{x}} = \mathrm{arg}\max_{\mathbf{x}}p(\mathbf{x}|\mathbf{z}) =
	\mathrm{arg}\max_{\mathbf{x}}p(\mathbf{z}|\mathbf{x}) = \mathrm{arg}\max_{\mathbf{x}}\mathcal{L}(\mathbf{z}|\mathbf{x}).
```

One can find the solution via maximization of the likelihood function ``\mathcal{L}(\mathbf{z}|\mathbf{x})``, which is defined via likelihoods of ``k`` independent measurements:  
```math
	\hat{\mathbf x} = \mathrm{arg} \max_{\mathbf{x}}\mathcal{L}(\mathbf{z}|\mathbf{x})=
	\mathrm{arg} \max_{\mathbf{x}} \prod_{i=1}^k \mathcal{N}(z_i|\mathbf{x},v_i).
```

It can be shown that the solution of the maximum a posteriori problem can be obtained by solving the following optimization problem, known as the weighted least-squares problem [[6, Sec. 9.3]](@ref refestimate):
```math
	\hat{\mathbf x} = \mathrm{arg}\min_{\mathbf{x}} \sum_{i=1}^k\cfrac{[z_i-h_i(\mathbf x)]^2}{v_i}.
```
The state estimate ``\hat{\mathbf x}`` representing the solution of the above optimization problem is known as the weighted least-squares estimator, the maximum likelihood and weighted least-squares estimator are equivalent to the maximum a posteriori solution [[5, Sec. 8.6]](@ref refestimate).

### Measurement Set
The typical set of measurements ``\mathcal{M}`` is defined according to type of measurement devices and includes:
* Legacy measurements:
  * active and reactive power flow ``\{M_{P_{ij}}, \; M_{P_{ji}} \; M_{Q_{ij}}, \; M_{Q_{ji}}\}, \; (i,j) \in \mathcal{E}``;
  * branch current magnitude ``\{M_{I_{ij}}, M_{I_{ji}} \}, \; (i,j) \in \mathcal{E}``;
  * active and reactive power injection ``\{M_{P_{i}}, \; M_{Q_{i}}\}, \; i \in \mathcal{H}``;
  * bus voltage magnitude ``\{M_{V_{i}} \}, \; i \in \mathcal{H}``.
* Phasor measurements provide by PMUs:
  * branch current ``\mathcal{M}_{\bar{I}_{ij}} = \{{M}_{{I}_{ij}}, \; {M}_{{\beta}_{ij}}\}, \; \mathcal{M}_{\bar{I}_{ji}} = \{{M}_{{I}_{ji}}, \; {M}_{{\beta}_{ji}}\},  \; (i,j) \in \mathcal{E}``;
  * bus voltage ``\mathcal{M}_{\bar{V}_{i}} = \{{M}_{{V}_{i}}, \; {M}_{{\theta}_{i}}\}, \; i \in \mathcal{H}``,
where each phasor measurement is represented by a pair of measurements in the polar coordinate system. More precisely, phasor measurement provided by PMU is formed by a magnitude, equal to the root mean square value of the signal, and phase angle [[9, Sec. 5.6]](@ref refestimate), where measurement errors are also related with magnitude and angle of the phasor. Thus, the PMU outputs phasor measurement in polar coordinates. In addition, PMU outputs can be observed in the rectangular coordinates with real and imaginary parts of the bus voltage and line current phasors, but in that case, the two measurements may be affected by correlated measurement errors [[9, Sec. 7.3]](@ref refestimate).

Each legacy measurement is described by non-linear measurement function ``h_i(\mathbf{x})``, where the state vector ``\mathbf{x}`` is given in polar coordinates. In contrast, phasor measurements can be described with both non-linear and linear measurement functions ``h_i(\mathbf{x})``, where the state vector ``\mathbf{x}`` can be given in polar or rectangular coordinates.

### State Variables
We observe complex bus voltages ``\bar V_i``, ``i \in \mathcal{H}`` as state variables:
```math
    \bar V_i = V_{i}\mathrm{e}^{\mathrm{j}\theta_{i}} = \Re {(\bar V_i)} + \mathrm{j} \Im{(\bar V_i)},
```
where ``\Re {(\bar V_i)}`` and ``\Im{(\bar V_i)}`` represent the real and imaginary components of the complex bus voltage ``\bar V_i``, respectively.   

Thus, the vector of state variables ``\mathbf{x}`` can be given in polar coordinates ``\mathbf x \equiv[\bm \theta,\mathbf V]``, where we observe bus voltage angles and magnitudes as state variables respectively:
```math
  \begin{aligned}
    \bm \theta&=[\theta_1,\dots,\theta_n]^T\\
    \mathbf V&=[V_1,\dots, V_n]^T.
  \end{aligned}    
```
The conventional state estimation model in the presence of legacy measurements usually implies above approach.

Furthermore, the vector of state variables ``\mathbf{x}`` can be given in rectangular coordinates ``\mathbf x \equiv[\mathbf{V}_\mathrm{re},\mathbf{V}_\mathrm{im}]``, where we can observe real and imaginary components of bus voltages as state variables:   
```math
  \begin{aligned}
    \mathbf{V}_\mathrm{re}&=\big[\Re(\bar{V}_1),\dots,\Re(\bar{V}_n)\big]^T\\
	  \mathbf{V}_\mathrm{im}&=\big[\Im(\bar{V}_1),\dots,\Im(\bar{V}_n)\big]^T.
  \end{aligned}       
```

---

## [Non-linear State Estimation](@id nonlinearse)
In the presence of both, legacy and phasor measurements, the system of equations:
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x})+\mathbf{u},
```
represents the system of non-linear equations. The Gauss-Newton method is typically used to solve the non-linear state estimation model defined using measurement functions ``\mathbf {h(x)}`` that precisely follow the physical laws that connect the measured variables and the state variables.  

Based on the available set of measurements ``\mathcal{M}``, the weighted least-squares estimator ``\hat{\mathbf x}``, i.e., the solution of the weighted least-squares problem, can be found using the Gauss-Newton method:
```math
		\Big[\mathbf J (\mathbf x^{(\nu)})^{T} \mathbf R^{-1} \mathbf J (\mathbf x^{(\nu)})\Big] \Delta \mathbf x^{(\nu)} =
		\mathbf J (\mathbf x^{(\nu)})^{T} \mathbf R^{-1} \mathbf r (\mathbf x^{(\nu)})        
```
```math
		\mathbf x^{(\nu+1)} = \mathbf x^{(\nu)} + \Delta \mathbf x^{(\nu)},
```
where ``\nu = \{0,1,2,\dots\} `` is the iteration index, ``\Delta \mathbf x \in \mathbb {R}^{s} `` is the vector of increments of the state variables, ``\mathbf J (\mathbf x)\in \mathbb {R}^{k \times s}`` is the Jacobian matrix of measurement functions ``\mathbf h (\mathbf x)`` at ``\mathbf x=\mathbf x^{(\nu)}``, ``\mathbf{R}\in \mathbb {R}^{k \times k}`` is a measurement error covariance matrix, and ``\mathbf r (\mathbf x) = \mathbf{z} - \mathbf h (\mathbf x)`` is the vector of residuals [[4, Ch. 10]](@ref refestimate). Note that, assumption that measurement errors are uncorrelated leads to the diagonal covariance matrix ``\mathbf {R}`` that corresponds to measurement variances.

The non-linear state estimation represents non-convex problem arising from the non-linear measurement functions [[7]](@ref refestimate). Due the fact that the values of state variables usually fluctuate in narrow boundaries, the non-linear model represents the mildly non-linear problem, where solutions are in a reasonable-sized neighborhood which enables the use of the Gauss-Newton method. The Gauss-Newton method can produce different rates of convergence, which can be anywhere from linear to quadratic [[8, Sec. 9.2]](@ref refestimate). The convergence rate in regards to power system state estimation depends of the topology and measurements, and if parameters are consistent (e.g., free bad data measurement set), the method shows near quadratic convergence rate [[4, Sec. 11.2]](@ref refestimate).

### Legacy Measurements
In the following, we provide expressions for measurement functions ``\mathbf h (\mathbf x)`` and corresponding Jacobian elements of the matrix ``\mathbf J (\mathbf x)`` related to legacy measurements, where state variables (i.e., unknown variables) are given in polar coordinates ``\mathbf x \equiv [\bm \theta, \mathbf V]``.

```@raw html
&nbsp;
```
#### Active and Reactive Power Flow Measurement Functions  
We start from the [unified branch model](@ref branchmodel):
```math
  \begin{bmatrix}
    \bar{I}_{ij} \\ \bar{I}_{ji}
  \end{bmatrix} =
  \begin{bmatrix}
    \cfrac{1}{\tau_{ij}^2}({y}_{ij} + y_{\text{s}ij}) & -\alpha_{ij}^*{y}_{ij}\\
    -\alpha_{ij}{y}_{ij} & {y}_{ij} + y_{\text{s}ij}
  \end{bmatrix}  
  \begin{bmatrix}
    \bar{V}_{i} \\ \bar{V}_{j}
  \end{bmatrix}.    
```
The complex branch currents can be written in the form:
```math
  \begin{aligned}
    \bar{I}_{ij} &= \cfrac{1}{\tau_{ij}^2} [g_{ij} + \text{j}(b_{ij} + b_{\text{s}i})] V_{i}\mathrm{e}^{\mathrm{j}\theta_{i}} -
    \cfrac{1}{\tau_{ij}} (g_{ij} + \text{j}b_{ij}) V_{j} \mathrm{e}^{\mathrm{j}(\theta_{j} + \phi_{ij})}\\
    \bar{I}_{ji} &= - \cfrac{1}{\tau_{ij}} (g_{ij} + \text{j}b_{ij}) V_{i} \mathrm{e}^{\mathrm{j}(\theta_{i} - \phi_{ij})} +
    [g_{ij} + \text{j}(b_{ij} + b_{\text{s}i})] V_{j} \mathrm{e}^{\mathrm{j}\theta_{j}}.
  \end{aligned}
```
The complex apparent powers are:
```math
  \begin{aligned}
    {S}_{ij} &= \bar{V}_{i}\bar{I}_{ij}^* =
    \cfrac{1}{\tau_{ij}^2} [g_{ij} - \text{j}(b_{ij} + b_{\text{s}i})] V_{i}^2 -
    \cfrac{1}{\tau_{ij}} (g_{ij} - \text{j}b_{ij}) V_{i}V_{j} \mathrm{e}^{\mathrm{j}(\theta_{i} - \theta_{j} - \phi_{ij})} \\
    {S}_{ji} &= \bar{V}_{j}\bar{I}_{ji}^* = [g_{ij} - \text{j}(b_{ij} + b_{\text{s}i})] V_{j}^2 -  
    \cfrac{1}{\tau_{ij}} (g_{ij} - \text{j}b_{ij}) V_{i} V_j \mathrm{e}^{\mathrm{j}(\theta_{j} -\theta_{i} + \phi_{ij})}.
  \end{aligned}    
```
The real components of the above complex expressions define active power flows:
```math
  \begin{aligned}
    P_{ij} &=
    \cfrac{g_{ij}}{\tau_{ij}^2} V_{i}^2 -
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right]V_{i}V_{j} \\
    P_{ji} &= g_{ij} V_{j}^2 -  
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij}- \phi_{ij})\right] V_{i} V_j,
  \end{aligned}    
```
where ``\theta_{ij}=\theta_{i}-\theta_{j}`` is the voltage angle difference between buses ``i`` and ``j``. The imaginary components define reactive power flows:
```math
  \begin{aligned}
    Q_{ij} &=
    -\cfrac{b_{ij} + b_{\text{s}i}}{\tau_{ij}^2} V_{i}^2 -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j}\\
    Q_{ji} &= -(b_{ij} + b_{\text{s}i}) V_{j}^2 +  
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j}.
  \end{aligned}    
```
Hence, the real and imaginary components of the complex apparent powers define the active and reactive power flow measurement functions. Thus, measurements:
```math
    \{M_{P_{ij}}, \; M_{P_{ji}} \; M_{Q_{ij}}, \; M_{Q_{ji}}\}, \; (i,j) \in \mathcal{E},
```
are associated with measurement functions:
```math
    h_{P_{ij}}(\cdot) \triangleq P_{ij}; \;\;\; h_{P_{ji}}(\cdot) \triangleq P_{ji}; \;\;\; h_{Q_{ij}}(\cdot) \triangleq Q_{ij}; \;\;\;
    h_{Q_{ji}}(\cdot) \triangleq Q_{ji}.
```
Jacobian expressions corresponding to the measurement function ``h_{P_{ij}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial \theta_{j}} =   
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial V_{i}} &=
    \cfrac{2g_{ij}}{\tau_{ij}^2} V_{i} -
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial V_{j}} &= -
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) + b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}    
```
Jacobian expressions corresponding to the measurement function ``h_{P_{ji}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial \theta_{j}} =
    \cfrac{1}{\tau_{ij}} \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) + b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial V_{i}} &=  -
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_j \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial V_{j}} &= 2g_{ij} V_{j}-
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \cos(\theta_{ij} - \phi_{ij}) - b_{ij} \sin(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}    
```
Jacobian expressions corresponding to the measurement function ``h_{Q_{ij}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\cdot)}}{\mathrm \partial \theta_{j}} = -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) + b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\cdot)}}{\mathrm \partial V_{i}} &= -
    2\cfrac{b_{ij} + b_{\text{s}i}}{\tau_{ij}^2} V_{i} -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{j}\\
    \cfrac{\mathrm \partial{h_{Q_{ij}}(\cdot)}}{\mathrm \partial V_{j}} &= -
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\sin(\theta_{ij} - \phi_{ij}) - b_{ij}\cos(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}    
```
Jacobian expressions corresponding to the measurement function ``h_{Q_{ji}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} &= -
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\cdot)}}{\mathrm \partial \theta_{j}} =
    \cfrac{1}{\tau_{ij}}  \left[g_{ij}\cos(\theta_{ij} - \phi_{ij}) - b_{ij}\sin(\theta_{ij} - \phi_{ij})\right] V_{i}V_{j} \\
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\cdot)}}{\mathrm \partial V_{i}} &=  
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{j}\\
    \cfrac{\mathrm \partial{h_{Q_{ji}}(\cdot)}}{\mathrm \partial V_{j}} &= -
    2(b_{ij} + b_{\text{s}i}) V_{j} +  
    \cfrac{1}{\tau_{ij}} \left[g_{ij} \sin(\theta_{ij} - \phi_{ij}) + b_{ij} \cos(\theta_{ij} - \phi_{ij})\right] V_{i}.
	\end{aligned}    
```

```@raw html
&nbsp;
```
#### Branch Current Magnitude Measurement Functions  
The current magnitudes at the branch ``(i,j) \in \mathcal{E}`` that connects buses ``i`` and ``j`` can be obtained using:  
```math
	  I_{ij} = \cfrac{\sqrt{P_{ij}^2 + Q_{ij}^2}}{V_i}
```
```math
    I_{ji} = \cfrac{\sqrt{P_{ji}^2 + Q_{ji}^2}}{V_j}.
```
It can be shown that current magnitudes are:
```math
    I_{ij} =\sqrt{ A_{\text{m}1}V_i^2 + B_{\text{m}1}V_j^2 - 2V_iV_j[C_{\text{m}1} \cos(\theta_{ij} - \phi_{ij}) - D_{\text{m}1}\sin(\theta_{ij} - \phi_{ij})]}
```
```math
    I_{ji} =\sqrt{ A_{\text{m}2}V_i^2 + B_{\text{m}2}V_j^2 - 2V_iV_j[C_{\text{m}2} \cos(\theta_{ij} - \phi_{ij}) + D_{\text{m}2}\sin(\theta_{ij} - \phi_{ij})]},
```
where:
```math
  \begin{aligned}
    A_{\text{m}1} &= \cfrac{g_{ij}^2+(b_{ij}+b_{si})^2}{\tau_{ij}^4}; \;\;\; B_{\text{m}1} =  \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2}; \;\;\;    
    C_{\text{m}1} = \cfrac{g_{ij}^2+b_{ij}(b_{ij}+b_{si})}{\tau_{ij}^3}; \;\;\; D_{\text{m}1} = \cfrac{g_{ij}b_{si}}{\tau_{ij}^3}\\
    A_{\text{m}2} &= \cfrac{g_{ij}^2+b_{ij}^2}{\tau_{ij}^2}; \;\;\; B_{\text{m}2} = g_{ij}^2+(b_{ij}+b_{si})^2; \;\;\;
    C_{\text{m}2} = \cfrac{g_{ij}^2+b_{ij}(b_{ij}+b_{si})}{\tau_{ij}}; \;\;\; D_{\text{m}2} = \cfrac{g_{ij}b_{si}}{\tau_{ij}}.
  \end{aligned}
```
Hence, measurements:
```math
    \{M_{I_{ij}}, \; M_{I_{ji}}\}, \; (i,j) \in \mathcal{E},
```
are associated with measurement functions:
```math
    h_{I_{ij}}(\cdot) \triangleq I_{ij}; \;\;\; h_{I_{ji}}(\cdot) \triangleq I_{ji}.
```
Jacobian expressions corresponding to the measurement function ``h_{I_{ij}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{I_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{I_{ij}}(\cdot)}}{\mathrm \partial \theta_{j}} =   
    \cfrac{V_i V_j [C_{\text{m}1}\sin(\theta_{ij} - \phi_{ij}) + D_{\text{m}1}\cos(\theta_{ij} - \phi_{ij})]}{h_{I_{ij}}(\cdot)} \\
    \cfrac{\mathrm \partial{h_{I_{ij}}(\cdot)}}{\mathrm \partial V_{i}} &=
    \cfrac{A_{\text{m}1}V_i - V_j[C_{\text{m}1}\cos(\theta_{ij} - \phi_{ij}) - D_{\text{m}1}\sin(\theta_{ij} - \phi_{ij})]}{h_{I_{ij}}(\cdot)} \\
    \cfrac{\mathrm \partial{h_{I_{ij}}(\cdot)}}{\mathrm \partial V_{j}} &=
    \cfrac{B_{\text{m}1}V_i - V_i[C_{\text{m}1}\cos(\theta_{ij} - \phi_{ij}) - D_{\text{m}1}\sin(\theta_{ij} - \phi_{ij})]}{h_{I_{ij}}(\cdot)} .
	\end{aligned}    
```
Jacobian expressions corresponding to the measurement function ``h_{I_{ji}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{I_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} &=-
    \cfrac{\mathrm \partial{h_{I_{ji}}(\cdot)}}{\mathrm \partial \theta_{j}} =   
    \cfrac{V_i V_j [C_{\text{m}2}\sin(\theta_{ij} - \phi_{ij}) - D_{\text{m}2}\cos(\theta_{ij}- \phi_{ij})]}{h_{I_{ji}}(\cdot)} \\
    \cfrac{\mathrm \partial{h_{I_{ji}}(\cdot)}}{\mathrm \partial V_{i}} &=
    \cfrac{A_{\text{m}2}V_i - V_j[C_{\text{m}2}\cos(\theta_{ij} - \phi_{ij}) + D_{\text{m}2}\sin(\theta_{ij} - \phi_{ij})]}{h_{I_{ji}}(\cdot)} \\
    \cfrac{\mathrm \partial{h_{I_{ji}}(\cdot)}}{\mathrm \partial V_{j}} &=
    \cfrac{B_{\text{m}2}V_i - V_i[C_{\text{m}2}\cos(\theta_{ij} - \phi_{ij}) + D_{\text{m}2}\sin(\theta_{ij} - \phi_{ij})]}{h_{I_{ji}}(\cdot)} .
	\end{aligned}    
```
Note that, in deregulation environment current magnitude measurements can be found in significant numbers, especially in distribution grids. The use of line current magnitude measurements can lead to various problems (e.g., the ''flat start'' will cause undefined Jacobian elements), which in turn may seriously deteriorate the performance of the state estimators [[3, Sec. 9.3]](@ref refestimate).

```@raw html
&nbsp;
```
#### Active and Reactive Injection Measurement Functions  
The active and reactive power injection into the bus ``i \in \mathcal{H} `` can be obtained using:
```math
  {S}_{i} =\bar{V}_{i}\bar{I}_{i}^* = P_i + \text{j}Q_i,
```
where:
```math
  \begin{aligned}
    {P}_{i} &={V}_{i}\sum\limits_{j \in \mathcal{H}_i} {V}_{j}(G_{ij}\cos\theta_{ij} + B_{ij}\sin\theta_{ij})\\
    {Q}_{i} &={V}_{i}\sum\limits_{j \in \mathcal{H}_i} {V}_{j}(G_{ij}\sin\theta_{ij} - B_{ij}\cos\theta_{ij}).     
	\end{aligned}
```
Hence, measurements:
```math
    \{M_{P_{i}}, \; M_{Q_{i}}\}, \; i \in \mathcal{H},
```
are associated with measurement functions:
```math
    h_{P_{i}}(\cdot) \triangleq P_{i}, \; h_{Q_{i}}(\cdot) \triangleq Q_{i}.
```
Jacobian expressions corresponding to the measurement function ``h_{P_{i}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} &=
    {V}_{i}\sum_{j \in \mathcal{H}_i} {V}_{j} (-G_{ij}\sin\theta_{ij}+B_{ij}\cos\theta_{ij}) - V_i^2B_{ii}\\
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial \theta_{j}} &=
    {V}_{i}{V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}) \\
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial V_{i}} &=
    \sum_{j \in \mathcal{H}_i} {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij} \sin\theta_{ij})+{V}_{i}G_{ii}\\
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial V_{j}} &=
    {V}_{i}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij}).
  \end{aligned}
```
Jacobian expressions corresponding to the measurement function ``h_{Q_{i}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{Q_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} &=
    {V}_{i}\sum_{j \in \mathcal{H}_i} {V}_{j}(G_{ij}\cos\theta_{ij}+B_{ij}\sin\theta_{ij})-V_i^2G_{ii}\\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\cdot)}}{\mathrm \partial \theta_{j}} &=
    {V}_{i}{V}_{j}(-G_{ij}\cos\theta_{ij}-B_{ij}\sin\theta_{ij}) \\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\cdot)}}{\mathrm \partial V_{i}} &=
    \sum_{j \in \mathcal{H}_i} {V}_{j}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij})-{V}_{i}B_{ii}\\
    \cfrac{\mathrm \partial{h_{Q_{i}}(\cdot)}}{\mathrm \partial V_{j}} &=
    {V}_{i}(G_{ij}\sin\theta_{ij}-B_{ij}\cos\theta_{ij}).
  \end{aligned}
```
```@raw html
&nbsp;
```
#### Bus Voltage Magnitude Measurement Functions
The bus voltage magnitude on the bus ``i \in \mathcal{H}`` simply defines corresponding measurement function. Hence, measurement:
```math
    \{M_{V_{i}}\}, \; i \in \mathcal{H},
```
is associated with measurement function:
```math
   h_{V_{i}}(\cdot) \triangleq V_{i}.
```
Jacobian expressions corresponding to the measurement function ``h_{V_{i}}(\cdot)`` are defined:  
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{{h_{V_{i}}(\cdot)}}} {\mathrm \partial \theta_{i}}=0; \;\;\;
    \cfrac{\mathrm \partial{{h_{V_{i}}(\cdot)}}} {\mathrm \partial \theta_{j}}=0  \\   	
   	\cfrac{\mathrm \partial{{h_{V_{i}}(\cdot)}}} {\mathrm \partial V_{i}}=1; \;\;\;
    \cfrac{\mathrm \partial{{h_{V_{i}}(\cdot)}}}{\mathrm \partial V_{j}}=0.
  \end{aligned}
```

### Phasor Measurements
In the majority of PMUs, the voltage and current phasors in polar coordinate system are regarded as ''direct'' measurements (i.e., output from the PMU). This representation delivers the more accurate state estimates in comparison to the rectangular measurement representation, but it requires larger computing time [[10]](@ref refestimate). This representation is called simultaneous state estimation formulation, where measurements provided by PMUs are handled in the same manner as legacy measurements [[11]](@ref refestimate). Measurement errors are uncorrelated, with measurement variances that correspond to each components of the phasor measurements (i.e., magnitude and angle).
```@raw html
&nbsp;
```
#### Bus Voltage Phasor Measurement Functions
The bus voltage phasor on the bus ``i \in \mathcal{H}`` in the polar coordinate system is described:
```math
    \bar V_i = V_{i}\mathrm{e}^{\mathrm{j}\theta_{i}},
```
and due the fact that the state vector is given in the polar coordinate system ``\mathbf x \equiv[\bm \theta, \mathbf V]``, measurements:
```math
    \mathcal{M}_{\bar{V}_{i}} = \{{M}_{{V}_{i}}, \; {M}_{{\theta}_{i}}\}, \; i \in \mathcal{H}
```
are associated with measurement functions:
```math
   h_{V_{i}}(\cdot) \triangleq V_{i}; \; h_{\theta_{i}}(\cdot) \triangleq \theta_{i}.
```
Jacobian expressions corresponding to the measurement function ``h_{{V}_{i}}(\cdot)`` are defined:  
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{{h_{{V}_{i}}(\cdot)}}}{\mathrm \partial \theta_{i}}=0;\;\;\;
    \cfrac{\mathrm \partial{{h_{{V}_{i}}(\cdot)}}}{\mathrm \partial \theta_{j}}=0 \\   	
   	\cfrac{\mathrm \partial{{h_{{V}_{i}}(\cdot)}}}{\mathrm \partial V_{i}}=1; \;\;\;
    \cfrac{\mathrm \partial{{h_{{V}_{i}}(\cdot)}}}{\mathrm\partial V_{j}}=0,
    \end{aligned}
```
while Jacobian expressions corresponding to the measurement function ``h_{\theta_i}(\cdot)`` are:  
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{{h_{\theta_i}(\cdot)}}}{\mathrm \partial \theta_{i}}=1;\;\;\;  
    \cfrac{\mathrm \partial{{h_{\theta_i}(\cdot)}}}{\mathrm \partial \theta_{j}}=0 \\   	
   	\cfrac{\mathrm \partial{{h_{\theta_i}(\cdot)}}}{\mathrm \partial V_{i}}=0; \;\;\;\;  
    \cfrac{\mathrm \partial{{h_{\theta_i}(\cdot)}}}{\mathrm\partial V_{j}}=0.
  \end{aligned}
```
```@raw html
&nbsp;
```
#### Branch Current Phasor Measurement Functions
The branch current phasors at the branch ``(i,j) \in \mathcal{E}`` that connects buses ``i`` and ``j`` in polar coordinates are defined as:
```math
  \begin{aligned}
	 \bar{I}_{ij}&=I_{ij}\mathrm{e}^{\mathrm{j}\beta_{ij}}\\
   \bar{I}_{ji}&=I_{ji}\mathrm{e}^{\mathrm{j}\beta_{ji}},
  \end{aligned}
```
where ``I_{ij}``, ``I_{ji}`` and ``\beta_{ij}``, ``\beta_{ji}`` are magnitudes and angles of the line current phasors, respectively. We defined branch current magnitudes, while current angles are:
```math
    \beta_{ij} = \mathrm{arctan}\Bigg[
    \cfrac{(A_{\text{a}1} \sin\theta_i + B_{\text{a}1} \cos\theta_i)V_i - [C_{\text{a}1} \sin(\theta_{j}+\phi_{ij}) + D_{\text{a}1}\cos(\theta_{j}+\phi_{ij})]V_j}
    {(A_{\text{a}1} \cos\theta_i - B_{\text{a}1} \sin\theta_i)V_i - [C_{\text{a}1} \cos(\theta_{j}+\phi_{ij}) - D_{\text{a}1} \sin(\theta_{j}+\phi_{ij})]V_j} \Bigg]   
```
```math
    \beta_{ji} = \mathrm{arctan}\Bigg[
    \cfrac{(A_{\text{a}2} \sin\theta_j + B_{\text{a}2} \cos\theta_j)V_j - [C_{\text{a}2} \sin(\theta_{i}-\phi_{ij}) + D_{\text{a}2}\cos(\theta_{i}-\phi_{ij})]V_i}
    {(A_{\text{a}2} \cos\theta_j - B_{\text{a}2} \sin\theta_j)V_j - [C_{\text{a}2} \cos(\theta_{i}-\phi_{ij}) - D_{\text{a}2} \sin(\theta_{i}-\phi_{ij})]V_i} \Bigg],   
```
where coefficients are as follows: 		
```math
  \begin{aligned}
    A_{\text{a}1} &= \cfrac{g_{ij}}{\tau_{ij}^2}; \;\;\; B_{\text{a}1} = \cfrac{b_{ij}+b_{\text{s}i}}{\tau_{ij}^2}; \;\;\;
    C_{\text{a}1} = \cfrac{g_{ij}}{\tau_{ij}}; \;\;\; D_{\text{a}1} = \cfrac{b_{ij}}{\tau_{ij}} \\
    A_{\text{a}2} &= g_{ij}; \;\;\; B_{\text{a}2} = b_{ij} + b_{\mathrm{s}i}; \;\;\;
    C_{\text{a}2} = \cfrac{g_{ij}}{\tau_{ij}}; \;\;\; D_{\text{a}2} = \cfrac{b_{ij}}{\tau_{ij}}
  \end{aligned}
```
Thus, measurements:
```math
    \mathcal{M}_{\bar{I}_{ij}} = \{{M}_{{I}_{ij}}, \; {M}_{{\beta}_{ij}}\}, \; \mathcal{M}_{\bar{I}_{ji}} = \{{M}_{{I}_{ji}}, \; {M}_{{\beta}_{ji}}\},  \; (i,j) \in \mathcal{E},
```
are associated with measurement functions:
```math
    h_{I_{ij}}(\cdot) \triangleq I_{ij}; \;\;\; h_{\beta_{ij}}(\cdot) \triangleq \beta_{ij}; \;\;\; h_{I_{ji}}(\cdot) \triangleq I_{ji}; \;\;\; h_{\beta_{ji}}(\cdot) \triangleq \beta_{ji}.
```
Jacobian expressions corresponding to the measurement function ``h_{\beta_{ij}}(\cdot)`` are defined:  
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\beta_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} &=
    \cfrac{A_{\text{m}1} V_i^2- [C_{\text{m}1} \cos(\theta_{ij}- \phi_{ij}) - D_{\text{m}1} \sin (\theta_{ij} - \phi_{ij}) ]V_iV_j}{h_{{I}_{ij}}^2(\cdot)} \\
    \cfrac{\mathrm \partial{h_{\beta_{ij}}(\cdot)}}{\mathrm \partial \theta_{j}} &=
    \cfrac{B_{\text{m}1} V_j^2 - [C_{\text{m}1} \cos (\theta_{ij} - \phi_{ij}) - D_{\text{m}1} \sin(\theta_{ij}- \phi_{ij})]V_iV_j}{h_{{I}_{ij}}^2(\cdot)} \\
    \cfrac{\mathrm \partial{h_{\beta_{ij}}(\cdot)}}{\mathrm \partial V_{i}} &= -
    \cfrac{[C_{\text{m}1} \sin (\theta_{ij} - \phi_{ij}) + D_{\text{m}1} \cos(\theta_{ij}- \phi_{ij})]V_j }{h_{{I}_{ij}}^2(\cdot)}\\
    \cfrac{\mathrm \partial{h_{\beta_{ij}}(\cdot)}}{\mathrm \partial V_{j}} &=
    \cfrac{[C_{\text{m}1} \sin (\theta_{ij} - \phi_{ij}) + D_{\text{m}1} \cos(\theta_{ij}- \phi_{ij})]V_i }{h_{{I}_{ij}}^2(\cdot)}.
  \end{aligned}
```
Jacobian expressions corresponding to the measurement function ``h_{\beta_{ji}}(\cdot)`` are defined:  
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\beta_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} &=
    \cfrac{A_{\text{m}2} V_i^2- [C_{\text{m}2} \cos(\theta_{ij}- \phi_{ij}) + D_{\text{m}2} \sin (\theta_{ij} - \phi_{ij}) ]V_iV_j}{h_{{I}_{ji}}^2(\cdot)} \\
    \cfrac{\mathrm \partial{h_{\beta_{ji}}(\cdot)}}{\mathrm \partial \theta_{j}} &=
    \cfrac{B_{\text{m}2} V_j^2 - [C_{\text{m}2} \cos (\theta_{ij} - \phi_{ij}) + D_{\text{m}2} \sin(\theta_{ij}- \phi_{ij})]V_iV_j}{h_{{I}_{ji}}^2(\cdot)} \\
    \cfrac{\mathrm \partial{h_{\beta_{ji}}(\cdot)}}{\mathrm \partial V_{i}} &= -
    \cfrac{[C_{\text{m}2} \sin (\theta_{ij} - \phi_{ij}) - D_{\text{m}2} \cos(\theta_{ij}- \phi_{ij})]V_j }{h_{{I}_{ji}}^2(\cdot)}\\
    \cfrac{\mathrm \partial{h_{\beta_{ji}}(\cdot)}}{\mathrm \partial V_{j}} &=
    \cfrac{[C_{\text{m}2} \sin (\theta_{ij} - \phi_{ij}) - D_{\text{m}2} \cos(\theta_{ij}- \phi_{ij})]V_i }{h_{{I}_{ji}}^2(\cdot)}.
  \end{aligned}
```

#### State Estimation Model
The non-linear state estimation model, used by JuliaGrid, implies the state vector in polar coordinates ``\mathbf x \equiv[\bm \theta,\mathbf V]``, where the vector of measurement functions ``\mathbf h (\mathbf x)`` and corresponding Jacobian elements of the matrix ``\mathbf J (\mathbf x)`` are expressed in the same coordinate system. Here, the vector of measurement values ``\mathbf z \in \mathbb {R}^{k}``, the vector of measurement functions ``\mathbf h(\mathbf x) \in \mathbb {R}^{k}`` and corresponding Jacobian matrix ``\mathbf {J}(\mathbf x) \in \mathbb {R}^{k \times n}`` are:
```math
    \mathbf z =
    \begin{bmatrix}    	 
      \mathbf z_{P_{ij}}\\[3pt]
      \mathbf z_{P_{ji}}\\[3pt]
      \mathbf z_{Q_{ij}}\\[3pt]
      \mathbf z_{Q_{ji}}\\[3pt]
      \mathbf z_{I_{ij}}\\[3pt]
      \mathbf z_{I_{ji}}\\[3pt]
      \mathbf z_{P_{i}}\\[3pt]
      \mathbf z_{Q_{i}}\\[3pt]
      \mathbf z_{V_{i}}\\[3pt]
      \mathbf z_{\theta_{i}}\\[3pt]
      \mathbf z_{\beta_{ij}}\\[3pt]      
      \mathbf z_{\beta_{ji}}   
    \end{bmatrix}; \;\;\;
    \mathbf h (\mathbf x)
    \begin{bmatrix}    	 
      \mathbf h_{P_{ij}}(\mathbf x)\\[3pt]
      \mathbf h_{P_{ji}}(\mathbf x)\\[3pt]
      \mathbf h_{Q_{ij}}(\mathbf x)\\[3pt]
      \mathbf h_{Q_{ji}}(\mathbf x)\\[3pt]
      \mathbf h_{I_{ij}}(\mathbf x)\\[3pt]
      \mathbf h_{I_{ji}}(\mathbf x)\\[3pt]
      \mathbf h_{P_{i}}(\mathbf x)\\[3pt]
      \mathbf h_{Q_{i}}(\mathbf x)\\[3pt]
      \mathbf h_{V_{i}}(\mathbf x)\\[3pt]
      \mathbf h_{\theta_{i}}(\mathbf x)\\[3pt]
      \mathbf h_{\beta_{ij}}(\mathbf x)\\[3pt]      
      \mathbf h_{\beta_{ji}}(\mathbf x)   
    \end{bmatrix}; \;\;\;
    \mathbf J(\mathbf x)=
    \begin{bmatrix}
      \mathbf {J}_{P_{ij}\theta}(\mathbf x) & \mathbf {J}_{P_{ij}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{P_{ji}\theta}(\mathbf x) & \mathbf {J}_{P_{ji}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{Q_{ij}\theta}(\mathbf x) & \mathbf {J}_{Q_{ij}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{Q_{ji}\theta}(\mathbf x) & \mathbf {J}_{Q_{ji}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{I_{ij}\theta}(\mathbf x) & \mathbf {J}_{I_{ij}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{I_{ji}\theta}(\mathbf x) & \mathbf {J}_{I_{ji}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{P_{i}\theta}(\mathbf x) & \mathbf {J}_{P_{i}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{Q_{i}\theta}(\mathbf x) & \mathbf {J}_{Q_{i}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{V_{i}\theta}(\mathbf x) & \mathbf {J}_{V_{i}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{\theta_{i}\theta}(\mathbf x) & \mathbf {J}_{\theta_{i}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{\beta_{ij}\theta}(\mathbf x) & \mathbf {J}_{\beta_{ij}V}(\mathbf x) \\[3pt]
      \mathbf {J}_{\beta_{ji}\theta}(\mathbf x) & \mathbf {J}_{\beta_{ji}V}(\mathbf x) \\[3pt]
	\end{bmatrix}.
```
Due to assumption of uncorrelated measurement errors (i.e., usual assumption), the measurement error covariance matrix ``\mathbf{R} \in \mathbb {R}^{k \times k}`` has the diagonal structure:
```math
	\mathbf R = \text{diag}	(
	\mathbf R_{P_{ij}},\; \mathbf R_{P_{ji}},\; \mathbf R_{Q_{ij}},\; \mathbf R_{Q_{ji}},\; \mathbf R_{I_{ij}},\; \mathbf R_{I_{ji}},\;
  \mathbf R_{P_{i}},\; \mathbf R_{Q_{i}},\; \mathbf R_{V_{i}},\; \mathbf R_{\theta_{i}},\; \mathbf R_{\beta_{ij}},\; \mathbf R_{\beta_{ji}}),
```
and each covariance sub-matrix of is the diagonal matrix that contains measurement variances. The solution of the described state estimation model is obtained using the iterative Gauss-Newton method.

JuliaGrid uses the above equation to compute bus voltage angles and magnitudes, where the slack bus is included in the formulation, where the angle of one reference bus is known. Consequently, the state vector ``\mathbf x \equiv[\bm \theta,\mathbf V]`` has ``s = 2n-1`` elements, while the corresponding column of the matrix ``\mathbf J(\mathbf x)`` is removed.

---

## [Linear State Estimation with PMUs](@id linearpmuse)
To recall, phasor measurement provided by PMU is formed by a magnitude and phase angle, where measurement errors are also related with magnitude and angle of the phasor. Thus, the PMU outputs phasor measurement in polar coordinates. In addition, PMU outputs can be observed in the rectangular coordinates with real and imaginary parts of the bus voltage and line current phasors, where the vector of state variables is given in rectangular coordinates ``\mathbf x \equiv[\mathbf{V}_\text{re},\mathbf{V}_\text{im}]``. Then, we obtain linear measurement functions with constant Jacobian elements. Unfortunately, direct inclusion in the conventional state estimation model is not possible due to different coordinate systems, however, this still represents the important advantage of phasor measurements. Thus, the JuliaGrid package provides linear state estimation with PMUs only.
```@raw html
&nbsp;
```
#### Bus Voltage Phasor Measurement Functions
The bus voltage phasor on the bus ``i \in \mathcal{H}`` in the rectangular coordinates is defined as:
```math
	\bar {V}_{i} = \Re(\bar{V}_{i}) +\text{j}\Im(\bar{V}_{i}) = V_{\text{re},i} +\text{j}V_{\text{im},i}.
```
The state vector is given in the rectangular coordinate system ``\mathbf x \equiv[\mathbf{V}_\text{re},\mathbf{V}_\text{im}]`` and the real and imaginary components directly define measurement functions. Hence, phasor measurement:
```math
    \mathcal{M}_{\bar{V}_{i}}, \; i \in \mathcal{H}
```
is associated with measurement functions:
```math
   h_{V_{\text{re},i}}(\cdot) \triangleq V_{\text{re},i}; \;\;\; h_{V_{\text{im},i}}(\cdot) \triangleq V_{\text{im},i}.
```
Jacobians expressions corresponding to the measurement function ``h_{V_{\text{re},i}}(\cdot)`` are defined:
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{h_{V_{\text{re},i}}(\cdot)}}{\mathrm \partial V_{\text{re},i}}=1; \;\;\;  
    \cfrac{\mathrm \partial{h_{V_{\text{re},i}}(\cdot)}}{\mathrm \partial V_{\text{re},j}}=0 \\
   	\cfrac{\mathrm \partial{h_{V_{\text{re},i}}(\cdot)}}{\mathrm \partial V_{\text{im},i}}=0;\;\;\;  
    \cfrac{\mathrm \partial{h_{V_{\text{re},i}}(\cdot)}}{\mathrm \partial V_{\text{im},j}}=0,    
  \end{aligned}    
```

while Jacobians expressions corresponding to the measurement function ``h_{V_{\text{im},i}}(\cdot)`` are:
```math
  \begin{aligned}
   	\cfrac{\mathrm \partial{h_{V_{\text{im},i}}(\cdot)}}{\mathrm \partial V_{\text{re},i}}=0;\;\;\;
    \cfrac{\mathrm \partial{h_{V_{\text{im},i}}(\cdot)}}{\mathrm \partial V_{\text{re},j}}=0 \\
   	\cfrac{\mathrm \partial{h_{V_{\text{im},i}}(\cdot)}}{\mathrm \partial V_{\text{im},i}}=1;\;\;\;
    \cfrac{\mathrm \partial{h_{V_{\text{im},i}}(\cdot)}}{\mathrm \partial V_{\text{im},j}}=0.    
  \end{aligned}    
```
```@raw html
&nbsp;
```
#### Branch Current Phasor Measurement Functions
The branch current phasors at the branch ``(i,j) \in \mathcal{E}`` that connects buses ``i`` and ``j`` in the rectangular coordinate system are given:
```math
  \begin{aligned}
    \bar{I}_{ij} &= \Re(\bar{I}_{ij}) +\mathrm{j}\Im(\bar{I}_{ij}) = I_{\text{re},ij} +\text{j}I_{\text{im},ij}. \\
    \bar{I}_{ji} &= \Re(\bar{I}_{ji}) +\mathrm{j}\Im(\bar{I}_{ji}) = I_{\text{re},ji} +\text{j}I_{\text{im},ji}.
  \end{aligned}    
```
Using the [unified branch model](@ref branchmodel), the real and imaginary components of the branch current phasors are:
```math
   I_{\text{re},ij} = \cfrac{g_{ij}}{\tau_{ij}^2} V_{\text{re},i} - \cfrac{b_{ij}+b_{\text{s}i}} {\tau_{ij}^2} V_{\text{im},i} -
  \left(\cfrac{g_{ij}}{\tau_{ij}} \cos\phi_{ij} - \cfrac{b_{ij}}{\tau_{ij}} \sin \phi_{ij}\right) V_{\text{re},j} +    
  \left(\cfrac{b_{ij}}{\tau_{ij}}\cos \phi_{ij} + \cfrac{g_{ij}}{\tau_{ij}}\sin \phi_{ij}\right)V_{\text{im},j}
```
```math
   I_{\text{im},ij} = \cfrac{b_{ij}+b_{\text{s}i}}{\tau_{ij}^2} V_{\text{re},i} + \cfrac{g_{ij}} {\tau_{ij}^2} V_{\text{im},i} -
  \left(\cfrac{b_{ij}}{\tau_{ij}} \cos\phi_{ij} + \cfrac{g_{ij}}{\tau_{ij}} \sin \phi_{ij}\right) V_{\text{re},j} -    
  \left(\cfrac{g_{ij}}{\tau_{ij}}\cos \phi_{ij} - \cfrac{b_{ij}}{\tau_{ij}}\sin \phi_{ij}\right)V_{\text{im},j}
```
```math
   I_{\text{re},ji} = g_{ij} V_{\text{re},j} - (b_{ij}+b_{\text{s}i}) V_{\text{im},j} -
  \left(\cfrac{g_{ij}}{\tau_{ij}} \cos\phi_{ij} + \cfrac{b_{ij}}{\tau_{ij}} \sin \phi_{ij}\right) V_{\text{re},i} +    
  \left(\cfrac{b_{ij}}{\tau_{ij}}\cos \phi_{ij} - \cfrac{g_{ij}}{\tau_{ij}}\sin \phi_{ij}\right)V_{\text{im},i}
```
```math
   I_{\text{im},ji} = (b_{ij}+b_{\text{s}i}) V_{\text{re},j} + g_{ij} V_{\text{im},j} -
  \left(\cfrac{b_{ij}}{\tau_{ij}} \cos\phi_{ij} - \cfrac{g_{ij}}{\tau_{ij}} \sin \phi_{ij}\right) V_{\text{re},i} -    
  \left(\cfrac{g_{ij}}{\tau_{ij}}\cos \phi_{ij} + \cfrac{b_{ij}}{\tau_{ij}}\sin \phi_{ij}\right)V_{\text{im},i}.
```
Hence, measurements:
```math
    \mathcal{M}_{\bar{I}_{ij}}, \; \mathcal{M}_{\bar{I}_{ji}},  \; (i,j) \in \mathcal{E},
```
are associated with measurement functions:
```math
    h_{I_{\text{re},ij}}(\cdot) \triangleq I_{\text{re},ij}; \;\;\; h_{I_{\text{im},ij}}(\cdot) \triangleq I_{\text{im},ij}; \;\;\;
    h_{I_{\text{re},ji}}(\cdot) \triangleq I_{\text{re},ji}; \;\;\; h_{I_{\text{im},ji}}(\cdot) \triangleq I_{\text{im},ji}.
```
Jacobians expressions corresponding to the measurement function ``h_{I_{\text{re},ij}}(\cdot)`` and ``h_{I_{\text{im},ij}}(\cdot)`` are defined:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{h_{I_{\text{re},ij}}(\cdot)}}{\mathrm \partial V_{\text{re},i}} &=
  \cfrac{\mathrm \partial{h_{I_{\text{im},ij}}(\cdot)}}{\mathrm \partial V_{\text{im},i}} = \cfrac{g_{ij}}{\tau_{ij}^2} \\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ij}}(\cdot)}} {\mathrm \partial V_{\text{re},j}} &=
  \cfrac{\mathrm \partial{h_{I_{\text{im},ij}}(\cdot)}} {\mathrm \partial V_{\text{im},j}} =
  - \left(\cfrac{g_{ij}}{\tau_{ij}} \cos\phi_{ij} - \cfrac{b_{ij}}{\tau_{ij}} \sin \phi_{ij}\right)\\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ij}}(\cdot)}}{\mathrm \partial V_{\text{im},i}} &=-
  \cfrac{\mathrm \partial{h_{I_{\text{im},ij}}(\cdot)}}{\mathrm \partial V_{\text{re},i}} =
  -\cfrac{b_{ij}+b_{\text{s}i}} {\tau_{ij}^2} \\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ij}}(\cdot)}}{\mathrm \partial V_{\text{im},j}} &= -
  \cfrac{\mathrm \partial{h_{I_{\text{im},ij}}(\cdot)}}{\mathrm \partial V_{\text{re},j}} =
  \left(\cfrac{b_{ij}}{\tau_{ij}}\cos \phi_{ij} + \cfrac{g_{ij}}{\tau_{ij}}\sin \phi_{ij}\right),
  \end{aligned}    
```
Jacobians expressions corresponding to the measurement function ``h_{I_{\text{re},ji}}(\cdot)`` and ``h_{I_{\text{im},ji}}(\cdot)`` are defined:
```math
  \begin{aligned}
  \cfrac{\mathrm \partial{h_{I_{\text{re},ji}}(\cdot)}}{\mathrm \partial V_{\text{re},i}} &=
  \cfrac{\mathrm \partial{h_{I_{\text{im},ji}}(\cdot)}}{\mathrm \partial V_{\text{im},i}} =
  - \left(\cfrac{g_{ij}}{\tau_{ij}} \cos\phi_{ij} + \cfrac{b_{ij}}{\tau_{ij}} \sin \phi_{ij}\right)\\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ji}}(\cdot)}} {\mathrm \partial V_{\text{re},j}} &=
  \cfrac{\mathrm \partial{h_{I_{\text{im},ji}}(\cdot)}} {\mathrm \partial V_{\text{im},j}} = g_{ij}\\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ji}}(\cdot)}}{\mathrm \partial V_{\text{im},i}} &= -
  \cfrac{\mathrm \partial{h_{I_{\text{im},ji}}(\cdot)}}{\mathrm \partial V_{\text{re},i}} =
  \left(\cfrac{b_{ij}}{\tau_{ij}}\cos \phi_{ij} + \cfrac{g_{ij}}{\tau_{ij}}\sin \phi_{ij}\right) \\
  \cfrac{\mathrm \partial{h_{I_{\text{re},ji}}(\cdot)}}{\mathrm \partial V_{\text{im},j}} &= -
  \cfrac{\mathrm \partial{h_{I_{\text{im},ji}}(\cdot)}}{\mathrm \partial V_{\text{re},j}} =
  -(b_{ij}+b_{\text{s}i}).
  \end{aligned}    
```
```@raw html
&nbsp;
```
#### State Estimation Model
Presented model represents system of linear equations, where solution can be found by solving the linear weighted least-squares problem:
```math
		\Big[\mathbf J^{T} \mathbf R^{-1} \mathbf J \Big] \mathbf x =
		\mathbf J ^{T} \mathbf R^{-1} \mathbf z.       
```
Here, the vector of measurement values ``\mathbf z \in \mathbb {R}^{k}`` and Jacobian matrix ``\mathbf {J} \in \mathbb {R}^{k \times n}`` are:
```math
    \mathbf z =
    \begin{bmatrix}    	 
      \mathbf z_{V_{\text{re},i}}\\[3pt]
      \mathbf z_{V_{\text{im},i}}\\[3pt]
      \mathbf z_{I_{\text{re},ij}}\\[3pt]
      \mathbf z_{I_{\text{im},ij}}\\[3pt]
      \mathbf z_{I_{\text{re},ji}}\\[3pt]
      \mathbf z_{I_{\text{im},ji}}  
    \end{bmatrix}; \;\;\;
    \mathbf J=
    \begin{bmatrix}
      \mathbf {J}_{V_{\text{re},i} V_{\text{re}}} & \mathbf {J}_{V_{\text{re},i} V_{\text{im}}} \\[3pt]
      \mathbf {J}_{V_{\text{im},i} V_{\text{re}}} & \mathbf {J}_{V_{\text{im},i} V_{\text{im}}} \\[3pt]
      \mathbf {J}_{I_{\text{re},ij} V_{\text{re}}} & \mathbf {J}_{I_{\text{re},ij} V_{\text{im}}} \\[3pt]
      \mathbf {J}_{I_{\text{im},ij} V_{\text{re}}} & \mathbf {J}_{I_{\text{im},ij} V_{\text{im}}} \\[3pt]
      \mathbf {J}_{I_{\text{re},ji} V_{\text{re}}} & \mathbf {J}_{I_{\text{re},ji} V_{\text{im}}} \\[3pt]
      \mathbf {J}_{I_{\text{im},ji} V_{\text{re}}} & \mathbf {J}_{I_{\text{im},ji} V_{\text{im}}}
	\end{bmatrix},
```
where measurement values are:
```math
  \begin{aligned}
    z_{V_{\text{re},i}} = z_{V_i} \cos z_{\theta_i}; \;\;\; z_{V_{\text{im},i}} = z_{V_i} \sin z_{\theta_i} \\
    z_{I_{\text{re},ij}} = z_{I_{ij}} \cos z_{\beta_{ij}}; \;\;\; z_{I_{\text{im},ij}} = z_{I_{ij}} \sin z_{\beta_{ij}} \\
    z_{I_{\text{re},ji}} = z_{I_{ji}} \cos z_{\beta_{ji}}; \;\;\; z_{I_{\text{im},ij}} = z_{I_{ji}} \sin z_{\beta_{ji}}.
  \end{aligned}
```

The main disadvantage of this approach is related to measurement errors, because measurement errors correspond to polar coordinates (i.e. magnitude and angle errors), and hence, the covariance matrix must be transformed from polar to rectangular coordinates. As a result, measurement errors of a single PMU are correlated and covariance matrix does not have diagonal form. Despite that, the measurement error covariance matrix is usually considered as diagonal matrix, which has the effect on the accuracy of the state estimation.

Using the classical theory of propagation of uncertainty [[12]](@ref refestimate), the variance in the rectangular coordinate system ``\sigma_{V_{\text{re},i}}^2`` can be obtained using variances in the polar coordinate system ``\sigma_{V_i}^2`` and ``\sigma_{\theta_i}^2`` as:
```math
    \sigma_{V_{\text{re},i}}^2 =
    \sigma_{V_i}^2 \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \cos z_{\theta_i}) \right]^2 +
    \sigma_{\theta_i}^2 \left[ \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \cos z_{\theta_i})\right]^2 =
    \sigma_{V_i}^2 (\cos z_{\theta_i})^2 + \sigma_{\theta_i}^2 (z_{V_i} \sin z_{\theta_i})^2.
```    
Using analogy, we can write:
```math
  \begin{aligned}
    \sigma_{V_{\text{im},i}}^2 &=
    \sigma_{V_i}^2 (\sin z_{\theta_i})^2 + \sigma_{\theta_i}^2 (z_{V_i} \cos z_{\theta_i})^2 \\
    \sigma_{I_{\text{re},ij}}^2 & =
    \sigma_{I_{ij}}^2 (\cos z_{\beta_{ij}})^2 + \sigma_{\beta_{ij}}^2 (z_{I_{ij}} \sin z_{\beta_{ij}})^2 \\
    \sigma_{I_{\text{im},ij}}^2 &=
    \sigma_{I_{ij}}^2 (\sin z_{\beta_{ij}})^2 + \sigma_{\beta_{ij}}^2 (z_{I_{ij}} \cos z_{\beta_{ij}})^2 \\
    \sigma_{I_{\text{re},ji}}^2 &=
    \sigma_{I_{ji}}^2 (\cos z_{\beta_{ji}})^2 + \sigma_{\beta_{ji}}^2 (z_{I_{ji}} \sin z_{\beta_{ji}})^2 \\
    \sigma_{I_{\text{im},ji}}^2 &=
    \sigma_{I_{ji}}^2 (\sin z_{\beta_{ji}})^2 + \sigma_{\beta_{ji}}^2 (z_{I_{ji}} \cos z_{\beta_{ji}})^2.
  \end{aligned}    
```
The covariance in the rectangular coordinate system is:
```math
    \sigma_{V_{\text{re},i}, V_{\text{im},i}}^2 = \sigma_{V_{\text{im},i}, V_{\text{re},i}}^2 =
    \sigma_{V_i}^2 \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \cos z_{\theta_i})
    \cfrac{\mathrm \partial} {\mathrm \partial z_{V_i}} (z_{V_i} \sin z_{\theta_i})  +
    \sigma_{\theta_i}^2 \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \cos z_{\theta_i})
    \cfrac{\mathrm \partial} {\mathrm \partial z_{\theta_i}} (z_{V_i} \sin z_{\theta_i}),
```
respectively:
```math
    \sigma_{V_{\text{re},i}, V_{\text{im},i}}^2 = \sigma_{V_{\text{im},i}, V_{\text{re},i}}^2 =
    \cos z_{\theta_i} \sin z_{\theta_i}(\sigma_{V_i}^2  - \sigma_{\theta_i}^2 z_{V_i}^2).
```    
Using analogy, we can write:
```math
  \begin{aligned}
    \sigma_{I_{\text{re},ij}, I_{\text{im},ij}}^2 &= \sigma_{I_{\text{im},ij}, I_{\text{re},ij}}^2  =
    \sin z_{\beta_{ij}} \cos z_{\beta_{ij}}(\sigma_{I_{ij}}^2  - \sigma_{\beta_{ij}}^2 z_{I_{ij}}^2) \\
    \sigma_{I_{\text{re},ji}, I_{\text{im},ji}}^2 &= \sigma_{I_{\text{im},ji}, I_{\text{re},ji}}^2  =
    \sin z_{\beta_{ji}} \cos z_{\beta_{ji}}(\sigma_{I_{ji}}^2  - \sigma_{\beta_{ij}}^2 z_{I_{ji}}^2).
  \end{aligned}    
```
The measurement error covariance matrix ``\mathbf{R} \in \mathbb {R}^{k \times k}`` has the structure:
```math
	\mathbf R = \text{diag}	(
    \mathbf R_{V_{\text{re},i}}, \; \mathbf R_{V_{\text{im},i}}, \; \mathbf R_{I_{\text{re},ij}}, \;
    \mathbf R_{I_{\text{im},ij}}, \; \mathbf R_{I_{\text{re},ji}}, \; \mathbf R_{I_{\text{im},ji}}).
```
The diagonal elements of the each covariance sub-matrix contains variances, wile covariances defined non-diagonal elements.

JuliaGrid supports two models related to the covariance matrix:
* covariance matrix ``\mathbf R`` contains measurement variances and covariances;
* measurement covariances are neglected, and covariance matrix ``\mathbf R`` has the diagonal structure.

Note that, inverse of the full covariance matrix ``\mathbf R`` requires larger computing time and uses more memory compared to the case where measurement covariances are neglected.

Further, in the absence of any angle measurement the number of state variables is ``s = 2n``. More precisely, linear state estimation with PMUs does not include the slack bus in the state estimation formulation.

---

## [Linear DC State Estimation](@id lineardcse)
As for the [DC Power Flow](@ref dcpowerflow), the DC model is obtained by linearisation of the non-linear model, where all bus voltage magnitudes are ``V_i \approx 1``, ``i \in \mathcal{H}``, and all shunt elements and branch resistances can be neglected. This implies that the DC model ignores the reactive powers and transmission losses and takes into account only the active powers. Therefore, the DC state estimation takes only bus voltage angles ``\mathbf x \equiv {\bm \theta}`` as state variables. Consequently, the number of state variables is ``s=n-1``, where one voltage angle represents the slack bus.

The set of DC model measurements ``\mathcal{M}`` involves:
* Legacy measurements:
  * active power flow ``\{M_{P_{ij}}, M_{P_{ji}}\}, \; (i,j) \in \mathcal{E}``;
  * active power injection ``\{M_{P_{i}}\}, \; i \in \mathcal{H}``;
* Phasor measurements provide by PMUs:
  * bus voltage angle ``\{{M}_{{\theta}_{i}}\}, \; i \in \mathcal{H}``.

```@raw html
  &nbsp;
```
#### Active Power Flow Measurement Functions
As for the [DC Power Flow](@ref dcpowerflow), the active power flow at the branch ``(i,j) \in \mathcal{E}`` that connects buses ``i`` and ``j`` can be obtained using:
```math
  \begin{aligned}
    P_{ij} &= \cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij})\\
    P_{ji} &= -\cfrac{1}{\tau_{ij} x_{ij}} (\theta_{i} -\theta_{j}-\phi_{ij}).
  \end{aligned}  
```
Hence, measurements:
```math
    \{M_{P_{ij}}, M_{P_{ji}}\},  \; (i,j) \in \mathcal{E},
```
are associated with measurement functions:
```math
    h_{P_{ij}}(\cdot) \triangleq P_{ij}; \;\;\; h_{P_{ji}}(\cdot) \triangleq P_{ji}
```
Jacobians expressions corresponding to the measurement function ``h_{P_{ij}}(\cdot)`` and ``h_{P_{ji}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{ij}}(\cdot)}}{\mathrm \partial \theta_{i}} = \cfrac{1}{\tau_{ij} x_{ij}}; \;\;\;
    \cfrac{\mathrm \partial{{h_{P_{ij}}}(\cdot)}}{\mathrm \partial \theta_{j}} = -\cfrac{1}{\tau_{ij} x_{ij}} \\
    \cfrac{\mathrm \partial{h_{P_{ji}}(\cdot)}}{\mathrm \partial \theta_{i}} = -\cfrac{1}{\tau_{ij} x_{ij}}; \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{ji}}}(\cdot)}}{\mathrm \partial \theta_{j}} = \cfrac{1}{\tau_{ij} x_{ij}}.
  \end{aligned}  
```

```@raw html
&nbsp;
```
#### Active Power Injection Measurement Functions
The active power injection into the bus ``i \in \mathcal{H} `` can be obtained using:
```math
   P_i = B_{ii}\theta_i + \sum_{j \in \mathcal{H}_i \setminus i} {B}_{ij} \theta_j + P_{\text{gs}i} + G_{\text{sh}i},
```
where ``\mathcal{H}_i \setminus i`` contains buses incident to the bus ``i``, excluding bus ``i``. Hence, measurement:
```math
    \mathcal{M}_{{P}_{i}},  \; i \in \mathcal{H},
```
is associated with measurement function:
```math
    h_{P_{i}}(\cdot) \triangleq P_{i}.
```
Jacobians expressions corresponding to the measurement function ``h_{P_{i}}(\cdot)`` are defined:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{P_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} = B_{ii}; \;\;\;
  \cfrac{\mathrm \partial{{h_{P_{i}}}(\cdot)}}{\mathrm \partial \theta_{j}} = {B}_{ij}.
  \end{aligned}  
```

```@raw html
&nbsp;
```
#### Bus Voltage Angle Measurement Functions
The measurement:
```math
    \mathcal{M}_{\theta_{i}},  \; i \in \mathcal{H},
```
is simply associated with measurement function:
```math
    h_{\theta_{i}}(\cdot) \triangleq \theta_{i},
```
with Jacobian expressions:
```math
  \begin{aligned}
    \cfrac{\mathrm \partial{h_{\theta_{i}}(\cdot)}}{\mathrm \partial \theta_{i}} = 1; \;\;\;
    \cfrac{\mathrm \partial{{h_{\theta_{i}}}(\cdot)}}{\mathrm \partial \theta_{j}} = 0.
  \end{aligned}  
```

```@raw html
&nbsp;
```
#### State Estimation Model
To recall, the measurement model is described as the system of equations:  
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x})+\mathbf{u},
```
where in the DC model constant terms exist on the right-hand side of ``\mathbf{h}(\mathbf{x})``. Consequently, we can write:
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x}) + \mathbf{c} +\mathbf{u}.
```

Presented model represents system of linear equations, where solution can be found by solving the linear weighted least-squares problem:
```math
		\Big[\mathbf J^{T} \mathbf R^{-1} \mathbf J\Big] \mathbf x =
		\mathbf J^{T} \mathbf R^{-1} (\mathbf z - \mathbf{c}).       
```
Here, the vector of measurement values ``\mathbf z \in \mathbb {R}^{k}``, the vector of constant terms ``\mathbf c \in \mathbb {R}^{k}``, the Jacobian matrix ``\mathbf {J} \in \mathbb {R}^{k \times n}`` and measurement error covariance matrix ``\mathbf{R} \in \mathbb {R}^{k \times k}`` are:
```math
    \mathbf z =
    \begin{bmatrix}    	 
      \mathbf z_{P_{ij}}\\[3pt]
      \mathbf z_{P_{ji}}\\[3pt]
      \mathbf z_{P_i}\\[3pt]
      \mathbf z_{\theta_i}  
    \end{bmatrix}; \;\;\;
    \mathbf c =
    \begin{bmatrix}    	 
      \mathbf c_{P_{ij}}\\[3pt]
      \mathbf c_{P_{ji}}\\[3pt]
      \mathbf c_{P_i}\\[3pt]
      \mathbf c_{\theta_i}  
    \end{bmatrix}; \;\;\;
    \mathbf J =
    \begin{bmatrix}
      \mathbf {J}_{P_{ij}} \\[3pt]
      \mathbf {J}_{P_{ji}} \\[3pt]
      \mathbf {J}_{P_{i}} \\[3pt]
      \mathbf {J}_{\theta_{i}}
	\end{bmatrix} \;\;\;
  \mathbf R = 	
    \begin{bmatrix}
	   \mathbf R_{\mathrm{P_{ij}}}  & \mathbf{0} & \mathbf{0} & \mathbf{0} \\
     \mathbf{0} & \mathbf R_{\mathrm{P_{ji}}}  & \mathbf{0}& \mathbf{0} \\
	   \mathbf{0} & \mathbf{0} & \mathbf R_{\mathrm{P_{i}}} & \mathbf{0}  \\
	   \mathbf{0} & \mathbf{0} &\mathbf{0} & \mathbf {R}_\mathrm{{\theta_{i}}}
	\end{bmatrix},
```
where elements of the vector ``\mathbf c`` are equal to:
```math
  \begin{aligned}
    c_{P_{ij}} &= -\cfrac{\phi_{ij}}{\tau_{ij}}; \;\;\; c_{P_{ji}} = \cfrac{\phi_{ij}}{\tau_{ij}} \\
    c_{P_{i}} &= P_{\text{gs}i} + G_{\text{sh}i}; \;\;\; c_{T_{i}} = T_{\text{ref}}.
  \end{aligned}      
```
In the DC state estimation method, the slack bus voltage angle ``T_{\text{ref}}`` is formulated as ``T_{\text{ref}} = 0``. If ``T_{\text{ref}} \neq 0`` then the bus voltage magnitude measurements must be shifted by ``T_{\text{ref}}`` value. Accordingly, the state estimator ``\mathbf x`` shifts by the same value ``T_{\text{ref}}`` as well. Finally, each sub-matrix of ``\mathbf R`` is the diagonal measurement error covariance matrix that contains measurement variances.

---

## [References](@id refestimate)
[1] F. C. Schweppe and D. B. Rom, "Power system static-state estimation, part II: Approximate model," IEEE Trans. Power Syst., vol. PAS-89, no. 1, pp. 125-130, Jan. 1970.

[2] A. Monticelli, "Electric power system state estimation," Proc. IEEE, vol. 88, no. 2, pp. 262-282, Feb. 2000.

[3] A. Abur and A. Exposito, Power System State Estimation: Theory and Implementation, ser. Power Engineering. Taylor & Francis, 2004.

[4] A. Monticelli, State Estimation in Electric Power Systems: A Generalized Approach, ser. Kluwer international series in engineering and computer science. Springer US, 1999.

[5] D. Barber, Bayesian Reasoning and Machine Learning. Cambridge University Press, 2012.

[6] A. Wood and B. Wollenberg, Power Generation, Operation, and Control, ser. A Wiley-Interscience publication. Wiley, 1996.

[7] Y. Weng, Q. Li, R. Negi, and M. Ilic, Semidefinite programming for power system state estimation," in Proc. IEEE PES General Meeting, July 2012, pp. 1-8.

[8] P. C. Hansen, V. Pereyra, and G. Scherer, Least squares data fitting with applications. JHU Press, 2013.

[9] A. G. Phadke and J. S. Thorp, Synchronized phasor measurements and their applications. Springer, 2008, vol. 1.

[10] G. N. Korres and N. M. Manousakis, State estimation and observability analysis for phasor measurement unit measured systems," IET Gener. Transm. Dis., vol. 6, no. 9, pp. 902-913, September 2012.

[11] A. Gomez-Exposito, A. Abur, P. Rousseaux, A. de la Villa Jaen, and C. Gomez-Quiles, On the use of PMUs in power system state estimation," Proc. IEEE PSCC, 2011.

[12] ISO-IEC-OIML-BIPM: Guide to the expression of uncertainty in measurement, 1992.
