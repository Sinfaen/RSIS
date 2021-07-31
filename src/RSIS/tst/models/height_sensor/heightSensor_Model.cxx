
#include "heightSensor_Model.hxx"

heightSensor_Model::heightSensor_Model()
    : generator(0), dist(0, 1)
{ }
heightSensor_Model::~heightSensor_Model() { }

std::string heightSensor_Model::getDescription() {
    return "Testing model:: Height Sensor";
}

RSISCmdStat heightSensor_Model::configModel() {
    if (params.limits[1] < params.limits[0]) {
        return RSISCmdStat::ERR;
    }
    dist = std::normal_distribution<double>(0, params.noise);
    return RSISCmdStat::OK;
}

RSISCmdStat heightSensor_Model::initModel() {
    // nothing to do here
    return RSISCmdStat::OK;
}

RSISCmdStat heightSensor_Model::stepModel() {
    data.measurement = in.signal + dist(generator);
    if (data.measurement < params.limits[0] ||
        data.measurement > params.limits[1])
    {
        out.inrange = false;
    } else {
        out.inrange = true;
    }
    return RSISCmdStat::OK;
}

RSISCmdStat heightSensor_Model::destroyModel() {
    return RSISCmdStat::OK;
}

void heightSensor_Model::reflect() {
    Reflect_heightSensor();
}
