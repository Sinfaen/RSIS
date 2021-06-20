
#include "BaseModel.hxx"
#include "PWM_interface.hxx"

using namespace RSIS::Scheduling;

class PWM_Model : public BaseModel {
public:
    PWM_Model();
    virtual ~PWM_Model();

    std::string getDescription();

    RSISCmdStat configModel();
    RSISCmdStat initModel();
    RSISCmdStat stepModel();
    RSISCmdStat destroyModel();

    void reflect();
protected:
    PWMIn     in;
    PWMOut    out;
    PWMData   data;
    PWMParams params;
};
