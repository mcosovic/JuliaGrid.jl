## [Bad Data Processing](@id baddata)
We refer the reader to section [State Estimation](@ref stateestimation) which precedes the analysis given here. Besides the state estimation algorithm, one of the essential state estimation routines is the bad data processing, whose main task is to detect and identify measurement errors, and eliminate them if possible. State Estimation algorithms proceed with the bad data processing after the estimation process is finished. This is usually done by processing the measurement residuals [[1, Ch. 5]](@ref refbaddata), and typically, the largest normalized residual test is used to identify bad data. The largest normalized residual test is performed after the algorithm converged in the repetitive process of identifying and eliminating bad data measurements one after another [[2]](@ref refbaddata). The bad data processing described bellow is associated with the commonly used weighted least-squares methods. More precisely, state estimation methods, such as least absolute value estimation, incorporate bad data processing as part of the state estimation procedure [[1, Ch. 5]](@ref refbaddata).

This section describes the largest normalized residual test based on the residual sensitivity analysis given in [[1, Sec. 5.7]](@ref refbaddata). Using weighted least-squares estimation methods (non-linear or linear), we obtained the state estimator ``\hat{\mathbf x}`` and elements of the measurement residual vector:
```math
    r_{i} = z_i - h_i(\hat{\mathbf x}), \;\;\; i \in \mathcal{M}.
```
Normalized residual is defined as:
```math
    c_{i} = \cfrac{|r_i|}{\sqrt{C_{ii}}}, \;\;\; i \in \mathcal{M},
```
where ``C_{ii}`` is the diagonal entries of the residual covariance matrix ``\mathbf C \in \mathbb{R}^{k \times k}``. Using a residual sensitivity matrix ``\mathbf S``, which represents the sensitivity of the measurement residuals to the measurement errors, the above equation became:
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
    c_{j} < \epsilon; \;\;\; c_j = \text{max} \{c_i, i \in \mathcal{M} \},
```
then the ``j``-th measurement will be suspected as the bad data and removed from the measurement set ``\mathcal{M}``, where ``\epsilon`` is a chosen the bad data identification threshold. State estimation can be repeated after the measurement is eliminating, where we compute the new state estimator ``\hat{\mathbf x}``. Thus, we have the repetitive process of identifying and eliminating bad data measurements one after another.

The elimination of measurements is possible only for the redundant measurements. Namely, removal of critical or non-redundant measurements from the measurement set will result in an unobservable system. Furthermore, the measurement residual of a critical measurement will be always approximately equal to zero [[1, Sec. 5.2]](@ref refbaddata). More precisely, if the measurement residual:
```math
    |r_{i}| \le \gamma, \;\;\; i \in \mathcal{M},
```
JuliaGrid marked the corresponding measurement as the critical, where ``\gamma`` is a predetermined critical measurement criteria.

---

## [Least Absolute Value Method](@id lav)
The least absolute value method represents the alternative estimation method which are more robust as compared to the weighted least-squares. The weighted least-squares state estimation problem is formulated based on certain assumptions about the measurement errors, robust estimators are expected to remain unbiased despite the existence of different types of measurement errors and outliers, making the bad data processing unnecessary [[1, Ch. 6]](@ref refbaddata). Note, there is no free lunch, robustness is commonly achieved at the expense of computational complexity.

In the case of least absolute value method, it can be shown that the problem can be formulated as a linear programming problem, and this section describes the method given in [[1, Sec. 6.5]](@ref refbaddata). Let us consider the system of linear equations:
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
                       & \;\;\; \mathbf {x_y} \succeq 0, \; \mathbf {x_v} \succeq 0 \\
                       & \;\;\; \mathbf {y} \succeq 0, \; \mathbf {v} \succeq 0.
  \end{aligned}
```

This can be written in compact form as a standard linear programming problem:
```math
  \begin{aligned}
    \text{minimize}& \;\;\; \mathbf g^T \mathbf t \\
    \text{subject\;to}& \;\;\; \mathbf{A} \mathbf{t} = \mathbf z \\
                       & \;\;\; \mathbf{t} \succeq 0,
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

---

## [References](@id refbaddata)
[1] A. Abur and A. Exposito, Power System State Estimation: Theory and Implementation, ser. Power Engineering. Taylor & Francis, 2004.

[2] G. N. Korres, A distributed multiarea state estimation, IEEE Trans. Power Syst., vol. 26, no. 1, pp. 73–84, Feb. 2011.
