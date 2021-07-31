
#include <random>
#include "BaseModel.hxx"
#include "heightSensor_interface.hxx"

using namespace RSIS::Scheduling;

class heightSensor_Model : public BaseModel {
public:
    heightSensor_Model();
    virtual ~heightSensor_Model();

    std::string getDescription();

    RSISCmdStat configModel();
    RSISCmdStat initModel();
    RSISCmdStat stepModel();
    RSISCmdStat destroyModel();

    void reflect();
protected:
    heightSensorIn in;
    heightSensorOut out;
    heightSensorData data;
    heightSensorParams params;

    std::mt19937 generator;
    std::normal_distribution<double> dist;
};
