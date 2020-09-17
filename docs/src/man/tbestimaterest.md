## [Bad Data Processing](@id baddata)
We refer the reader to section [State Estimation](@ref stateestimation) which precedes the analysis given here. Besides the state estimation algorithm, one of the essential state estimation routines is the bad data processing, whose main task is to detect and identify measurement errors, and eliminate them if possible. State Estimation algorithms proceed with the bad data processing after the estimation process is finished. This is usually done by processing the measurement residuals [[1, Ch. 5]](@ref refrestestimate), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after the algorithm converged in the repetitive process of identifying and eliminating bad data measurements one after another [[2]](@ref refrestestimate). The bad data processing described below is associated with the commonly used weighted least-squares methods. More precisely, state estimation methods, such as the least absolute value estimation, incorporate bad data processing as part of the state estimation procedure [[1, Ch. 5]](@ref refrestestimate).

This section describes the largest normalized residual test based on the residual sensitivity analysis given in [[1, Sec. 5.7]](@ref refrestestimate). Using weighted least-squares estimation methods (non-linear or linear), we obtained the state estimator ``\hat{\mathbf x}`` and elements of the measurement residual vector:
```math
    r_{i} = z_i - h_i(\hat{\mathbf x}), \;\;\; i \in \mathcal{M}.
```
Normalized residual is defined as:
```math
    c_{i} = \cfrac{|r_i|}{\sqrt{C_{ii}}}, \;\;\; i \in \mathcal{M},
```
where ``C_{ii}`` is the diagonal entries of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}``. Using a residual sensitivity matrix ``\mathbf S``, which represents the sensitivity of the measurement residuals to the measurement errors, the above equation becomes:
```math
    c_{i} = \cfrac{|r_i|}{\sqrt{S_{ii}R_{ii}}}, \;\;\; i \in \mathcal{M},
```
where:
```math
    \mathbf C = \mathbf S \mathbf R = \mathbf R - \mathbf J [\mathbf J^T \mathbf R^{-1} \mathbf J]^{-1} \mathbf J^T.
```
Note that only the diagonal entries of ``\mathbf C`` are needed. To obtain the inverse:
```math
    [\mathbf J^T \mathbf R^{-1} \mathbf J]^{-1},
```
the JuliaGrid package uses a computationally efficient sparse inverse method to obtain only the necessary elements of the inverse. However, if the largest normalized residual:
```math
    c_{j} \ge \epsilon; \;\;\; c_j = \text{max} \{c_i, i \in \mathcal{M} \},
```
then the ``j``-th measurement will be suspected as the bad data and removed from the measurement set ``\mathcal{M}`` if possible, where ``\epsilon`` is a chosen the bad data identification threshold. State estimation can be repeated after the measurement is eliminated, in order to compute the new state estimate ``\hat{\mathbf x}``.  Thus, we have the iterative process that sequentially identifies and eliminates bad data measurements one after another.

The elimination of measurements is possible only for the redundant measurements. Namely, the removal of critical or non-redundant measurements from the measurement set will result in an unobservable system. Furthermore, the measurement residual of a critical measurement will be always approximately equal to zero [[1, Sec. 5.2]](@ref refrestestimate). More precisely, if the measurement residual:
```math
    |r_{i}| \le \gamma, \;\;\; i \in \mathcal{M},
```
JuliaGrid designates the corresponding measurement as critical, where ``\gamma`` is a predetermined critical measurement criteria.

---

## [Least Absolute Value Method](@id lav)
The least absolute value method represents an alternative estimation method which is more robust as compared to the weighted least-squares. The weighted least-squares state estimation problem is formulated based on certain assumptions about the measurement errors, while robust estimators are expected to remain unbiased despite the existence of different types of measurement errors and outliers, making the bad data processing unnecessary [[1, Ch. 6]](@ref refrestestimate). Note that there is no free lunch, robustness is commonly achieved at the expense of computational complexity.

In the case of least absolute value method, it can be shown that the problem can be formulated as a linear programming problem, and this section describes the method given in [[1, Sec. 6.5]](@ref refrestestimate). Let us consider the system of linear equations:
```math
  \mathbf{z}=\mathbf{h}(\mathbf{x})+\mathbf{u},
```
where ``\mathbf {x}=[x_1,\dots,x_{s}]^{T}`` is the vector of the state variables, ``\mathbf{h}(\mathbf{x})=`` ``[h_1(\mathbf{x})``, ``\dots``, ``h_k(\mathbf{x})]^{{T}}`` is the vector of linear functions, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors. Then, the least absolute value state estimator ``\hat{\mathbf x}`` is defined as the solution of the optimization problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf a^T |\mathbf r(\mathbf x)|\\
    \text{subject\;to}& \;\;\; \mathbf{z} - \mathbf{J}\mathbf{x} =\mathbf r(\mathbf x),
  \end{aligned}
```
where ``\mathbf a \in \mathbb {R}^{k}`` is the vector with all entries equal to one, ``\mathbf J \in \mathbb {R}^{k \times s}`` is the Jacobian matrix of measurement functions ``\mathbf h (\mathbf x)``, and ``\mathbf r (\mathbf x)`` is the vector of measurement residuals. Further, we define ``\bm \eta``:
```math
  |\mathbf r(\mathbf x)| \preceq \bm \eta,
```
and replace the above inequality by two equalities via the introduction of two non-negative slack variables ``\mathbf q \in \mathbb {R}_{\ge 0}^{k}`` and ``\mathbf w \in \mathbb {R}_{\ge 0}^{k}``:
```math
  \begin{aligned}
    \mathbf r(\mathbf x) - \mathbf q &= -\bm \eta \\
    \mathbf r(\mathbf x) + \mathbf w &= \bm \eta.
  \end{aligned}
```
Let us now define four additional non-negative variables:
```math
  \begin{aligned}
    \mathbf {x_y} \in \mathbb {R}_{\ge 0}^{s}; \;\;\; \mathbf {x_v} \in \mathbb {R}_{\ge 0}^{s} \\   
    \mathbf {y} \in \mathbb {R}_{\ge 0}^{k}; \;\;\; \mathbf {v} \in \mathbb {R}_{\ge 0}^{k},
  \end{aligned}
```
where:
```math
  \begin{aligned}
    \mathbf {x} &= \mathbf {x_y} - \mathbf {x_v} \\
    \mathbf r(\mathbf x) &= \mathbf {y} - \mathbf {v} \\
    \mathbf {y} &= \cfrac{1}{2} \mathbf q \\
    \mathbf {v} &= \cfrac{1}{2} \mathbf w.
  \end{aligned}
```
Then, the above two equalities become:
```math
  \begin{aligned}
    \mathbf r(\mathbf x) - 2\mathbf y &= -2\bm \eta \\
    \mathbf r(\mathbf x) + 2\mathbf v &= 2\bm \eta,
  \end{aligned}
```
that is:
```math
  \begin{aligned}
    \mathbf y + \mathbf v = \bm \eta; \;\;\; \mathbf r(\mathbf x) = \mathbf y - \mathbf v.
  \end{aligned}
```

Hence, the optimization problem can be written:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf a^T (\mathbf y + \mathbf v)\\
    \text{subject\;to}& \;\;\; \mathbf{J}(\mathbf {x_y} - \mathbf {x_v}) + \mathbf y - \mathbf v = \mathbf{z}   \\
                       & \;\;\; \mathbf {x_y} \succeq \mathbf 0, \; \mathbf {x_v} \succeq \mathbf 0 \\
                       & \;\;\; \mathbf {y} \succeq \mathbf 0, \; \mathbf {v} \succeq \mathbf 0.
  \end{aligned}
```

This can be written in compact form as a standard linear programming problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf g^T \mathbf t \\
    \text{subject\;to}& \;\;\; \mathbf{A} \mathbf{t} = \mathbf z \\
                       & \;\;\; \mathbf{t} \succeq \mathbf 0,
  \end{aligned}
```
where:
```math
  \mathbf g =
  \begin{bmatrix}
    \mathbf 0_{s} \\ \mathbf 0_{s} \\ \mathbf 1_{k} \\ \mathbf 1_{k}
  \end{bmatrix}; \;\;\;
  \mathbf t =
  \begin{bmatrix}
    \mathbf {x_y} \\ \mathbf {x_v} \\ \mathbf {y} \\ \mathbf {v}
  \end{bmatrix}; \;\;\;
  \mathbf A =
  \begin{bmatrix}
    \mathbf{J} & -\mathbf{J} & \mathbf{E} & -\mathbf{E}
  \end{bmatrix}.
```
Here, the all-zero vector ``\mathbf 0_{s}`` is of dimension ``s``, the all-one vector ``\mathbf 1_{k}`` is of dimension ``k`` and ``\mathbf{E}`` is the identity matrix of dimension ``k \times k``. After solving the above linear programming problem, we reveal the state estimator:
```math
    \hat{\mathbf {x}} = \mathbf {x_y} - \mathbf {x_v}.
```
Note that the non-linear least absolute value state estimation is based on the successive set of linear programming problems, where we reveal state variables increments:
```math
    \mathbf {\mathbf \Delta x} = \mathbf {\mathbf \Delta x_y} - \mathbf {\mathbf \Delta x_v}.
```

---

## [Observability Analysis](@id observability)
Observability analysis in power systems is commonly performed on the linear decoupled measurement model [[14, Ch. 7]](@ref refrestestimate). Its function is to decide if the given set of measurements ``\mathcal{M}`` is sufficient to solve the system. When the given set of measurements ``\mathcal{M}`` is not sufficient, it must identify all the possible observable islands
that can be independently solved [[4]](@ref refrestestimate).

The JuliaGrid uses the observability analysis with the restore routine proposed in the papers [[5]](@ref refrestestimate) and [[6]](@ref refrestestimate), where pseudo-measurements are chosen in place of measurements that are marked as out-of-service in the input data.

### Linear DC State Estimation
We observe the set of measurements ``\mathcal{M}`` in the DC framework:
* Legacy measurements:
  * active power flow ``\{M_{P_{ij}}, M_{P_{ji}}\}, \; (i,j) \in \mathcal{E}``;
  * active power injection ``\{M_{P_{i}}\}, \; i \in \mathcal{H}``;
* Phasor measurements provided by PMUs:
  * bus voltage angle ``\{{M}_{{\theta}_{i}}\}, \; i \in \mathcal{H}``.

To recall, the measurement model can be described as:
```math
  \mathbf{z}=\mathbf J \bm \theta + \mathbf{c} + \mathbf{u},
```
where ``\bm {\theta}=[\theta_1,\dots,\theta_{s}]^{T}`` is the vector of the state variables, ``\mathbf J \in \mathbb{R}^{k \times s}`` is the measurement Jacobian matrix, ``\mathbf c \in \mathbb {R}^{k}`` is the vector of constant terms, ``\mathbf{z} = [z_1,\dots,z_k]^{\mathrm{T}}`` is the vector of measurement values, and ``\mathbf{u} = [u_1,\dots,u_k]^{\mathrm{T}}`` is the vector of uncorrelated measurement errors.

For observability purposes, we consider the Jacobian matrix ``\mathbf J``. The network is observable if:
```math
  \text{rank}(\mathbf J) = s,
```
where the slack bus is always included in the measurement model, as well as its equation. Note that the condition provides a necessary but not sufficient condition for observability. For most power systems under normal operating conditions, observability condition will guarantee a reliable state estimate [[6]](@ref refrestestimate). More precisely, guaranteeing observability by the condition is not the same as guaranteeing a good estimation of the system state. This is so because numerical problems may deteriorate the estimation [[7]](@ref refrestestimate).

If the system is unobservable:
```math
  \text{rank}(\mathbf J) < s,
```
the  observability  analysis  must  identify all  the  possible  observable  islands  that  can  be  independently solved, where an observable island is defined as follows: An observable island is a part of the power system for which the flows across all branches of the observable island can be calculated from the set of available measurements, independent of the values adopted for angular reference [3, Sec. 7.1.1]. Once the islands are determined, the observability analysis merges these islands in a way to protect previously-determined observable states from being altered by the new set of equations defined by the additional measurements. In general, this can be achieved by ensuring that the set of new measurements is a non-redundant set [[3, Sec. 7.3.2]](@ref refrestestimate),  i.e., the set of equations must be linearly independent with regard to the global system. The aim of the observability restoration is to find this non-redundant set.

#### Determination of Observable Islands
The JuliaGrid uses several island detection algorithms:
* the topological method based on the multi-stage procedure [[11]](@ref refrestestimate),
* the Gaussian belief propagation based method [[12]](@ref refrestestimate) (source code available, releases with v0.0.4).

The topological method allows the identification of several types of islands, on the basis of which it will be executed observability restoration. The simplest structure of the observable islands is formed using all the active power flow measurements to identify the flow islands [[6]](@ref refrestestimate). Then, if an active power injection measurement affects only two flow islands, these islands can be merged into a single island. Finally, JuliaGrid allows the formation of maximal islands as the largest region in which an unobservable system is partitioned [[5]](@ref refrestestimate).

#### Observability Restoration
As a result, we obtain the power system divided into ``n_{\text{i}}`` flow islands. Next, we observe the set of measurements ``\mathcal{M}_\text{b}`` that includes:
* active power injection measurements at boundary buses,
* bus voltage angle measurements.
Let us introduce the matrix ``\mathbf W_{\text{b}} \in \mathbb{R}^{n_{\text{b}} \times n_{\text{i}}}``, where ``n_{\text{b}} = |\mathcal{M}_\text{b}|`` is the total number of measurements from the set ``\mathcal{M}_\text{b}``. This matrix can be viewed as the Jacobian of a reduced network having ``n_{\text{i}}`` columns associated with flow islands, and ``n_{\text{b}}`` rows related to the set ``\mathcal{M}_\text{b}``. Measurement functions related to the set ``\mathcal{M}_\text{b}`` define the Jacobian matrix ``\mathbf J_\text{b}``, where the matrix ``\mathbf W_{\text{b}}`` is formed by summing the columns of ``\mathbf J_\text{b}`` belonging to a particular flow island [[6]](@ref refrestestimate).

Furthermore, we define the reduced Jacobian matrix ``\mathbf W_{\text{p}} \in \mathbb{R}^{n_{\text{p}} \times n_{\text{i}}}`` associated with the set of candidate pseudo-measurements ``\mathcal{M}_\text{p}``:
* active power flow measurements between boundary buses,
* active power injection measurements at unmeasured boundary buses,
* bus voltage angle measurements at unmeasured boundary buses,
where ``n_{\text{p}} = |\mathcal{M}_\text{p}|`` is the total number of candidate pseudo-measurements from the set ``\mathcal{M}_\text{p}``. As before, measurement functions related to the set ``\mathcal{M}_\text{p}`` define the Jacobian matrix ``\mathbf J_\text{p}``, where the matrix ``\mathbf W_{\text{p}}`` is formed by summing the columns of ``\mathbf J_\text{p}`` belonging to a particular flow island.

Thus, we form the reduced Jacobian matrix as:
```math
  \mathbf W_{\text{bp}} = \begin{bmatrix} \mathbf W_{\text{b}} \\ \mathbf W_{\text{p}} \end{bmatrix},
```
and the corresponding Gram matrix:
```math
  \mathbf M_{\text{bp}} = \mathbf W_{\text{bp}} \mathbf W_{\text{bp}}^T.
```
Let ``\mathbf M_{\text{bp}}`` be decomposed into its ``\mathbf Q`` and ``\mathbf R`` factors. Non-redundant measurements correspond to non-zero diagonal elements in ``\mathbf R``. More precisely, if the diagonal element:
```math
    |R_{ii}| < \epsilon,
```
JuliaGrid marks the corresponding measurement as redundant, where ``\epsilon`` is a predetermined zero pivot threshold. The minimal set of pseudo-measurements for observability restoration corresponds to the non-zero diagonal elements at positions related to the candidate pseudo-measurements.   

Note that the incorrect choice of the zero pivot threshold may deteriorate observability restoration. Also, it can happen that the set of pseudo-measurements ``\mathcal{M}_\text{p}`` are not sufficient for observability restoration.

---

## [Optimal PMU Placement](@id optimalpmu)
The JuliaGrid uses the optimal PMU placement algorithm proposed in [[9]](@ref refrestestimate). The optimal placement of PMUs is formulated as a problem of integer linear programming, as follows:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \sum_{i=1}^n x_i\\
    \text{subject\;to}& \;\;\; \mathbf A \mathbf x \ge \mathbf b.
  \end{aligned}
```
Here, the vector ``\mathbf x = [x_1,\dots,x_n]^T`` is the optimization variable, where ``x_i \in \mathbb{F} = \{0,1\}`` is the PMU placement or a binary decision variable related to the bus ``i \in \mathcal{H}``. The all-one vector ``\mathbf b`` is of dimension ``n``. The binary connectivity matrix ``\mathbf A \in \mathbb{F}^{n \times n}`` can be directly obtained from the bus admittance matrix ``\mathbf Y`` by transforming its entries into binary form [[10]](@ref refrestestimate).

As a result, we observe the binary vector ``\mathbf x = [x_1,\dots,x_n]^T``, where ``x_i = 1``, ``i \in \mathcal{H}``, suggests that we should place a PMU at bus ``i``. Here, the objective of placing PMUs in the power system is to decide a minimal set of PMUs such that the whole system is observable without legacy measurements [[9]](@ref refrestestimate).

---

## [References](@id refrestestimate)
[1] A. Abur and A. Exposito, *Power System State Estimation: Theory and Implementation*, ser. Power Engineering. Taylor & Francis, 2004.

[2] G. N. Korres, "A distributed multiarea state estimation," *IEEE Trans. Power Syst.*, vol. 26, no. 1, pp. 73–84, Feb. 2011.

[3] A. Monticelli, *State Estimation in Electric Power Systems: A Generalized Approach*, ser. Kluwer international series in engineering and computer science. Springer US, 1999.

[4] B. Gou, "Jacobian matrix-based observability analysis for state estimation," *IEEE Trans. Power Syst.*, vol. 21, no. 1, pp. 348–356, Feb. 2006.

[5] G. C. Contaxis and G. N. Korres, "A Reduced Model for Power System Observability Analysis and Restoration," *IEEE Trans. Power Syst.*, vol. 3, no. 4, pp. 1411-1417, Nov. 1988.

[6] N. M. Manousakis and G. N. Korres, "Observability analysis for power systems including conventional and phasor measurements," *in Proc. MedPower 2010*, Agia Napa, 2010, pp. 1-8.

[7] G. N. Korres, "Observability Analysis Based on Echelon Form of a Reduced Dimensional Jacobian Matrix," *IEEE Trans. Power Syst.*, vol. 26, no. 4, pp. 2572-2573, Nov. 2011.

[8] M. C. de Almeida, E. N. Asada, and A. V. Garcia, "Power system observability analysis based on gram matrix and minimum norm solution," *IEEE Trans. Power Syst.*, vol. 23, no. 4, pp. 1611–1618, Nov. 2008.

[9] B. Gou, "Optimal placement of PMUs by integer linear programming," *IEEE Trans. Power Syst.*, vol. 23, no. 3, pp. 1525–1526, Aug. 2008.

[10] B. Xu and A. Abur, "Observability analysis and measurement placement for systems with PMUs," *in Proc. IEEE PES PSCE*, New York, NY, 2004, pp. 943-946 vol.2.

[11] H. Horisberger, "Observability analysis for power systems with measurement deficiencies," *IFAC Proceedings Volumes*, vol. 18, no. 7, pp.51–58, 1985.

[12] M. Cosovic and D. Vukobratovic, "Observability analysis for large-scale power systems using factor graphs", arXiv:1907.10338 (2019).
