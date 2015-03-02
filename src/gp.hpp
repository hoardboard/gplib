#ifndef GPLIB_GP
#define GPLIB_GP

#include <armadillo>
#include <vector>
#include <memory>

namespace gplib {

    class kernel {
    public:
      virtual ~kernel() = 0;
      virtual arma::mat eval(const arma::mat& X, const arma::mat& Y,
          size_t id_out1=0, size_t id_out2=0) const = 0;
      virtual arma::mat derivate(size_t param_id, const arma::mat& X,
          const arma::mat& Y, size_t id_out1=0, size_t id_out2=0) const = 0;
      virtual size_t n_params() const = 0;
      virtual void set_params(const std::vector<double>& params) = 0;
      virtual std::vector<double> get_params() const = 0;
      virtual std::vector<double> set_lower_bounds()  = 0;
      virtual std::vector<double> get_lower_bounds() const = 0;
      virtual std::vector<double> set_upper_bounds()  = 0;
      virtual std::vector<double> get_upper_bounds() const = 0;
    };

    class gp_reg {
    private:
      struct implementation;
      implementation* pimpl;
    public:
      gp_reg();
      ~gp_reg();
      void setkernel(const std::shared_ptr<kernel>& k);
      std::shared_ptr<kernel> getkernel() const;
      void set_trainingSet(const arma::mat &X, const arma::vec& y);
      void train();
      mv_gauss full_predict(const arma::mat& new_data) const;
      arma::vec predict(const arma::mat& new_data) const;
    };
};

#endif
