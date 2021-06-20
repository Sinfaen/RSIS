
#include "PWM_Model.hxx"
#include "TimeManager.hxx"

PWM_Model::PWM_Model() { }
PWM_Model::~PWM_Model() { }

std::string PWM_Model::getDescription() {
    return "Pulse Width Modulated Output Block\n";
}

RSISCmdStat PWM_Model::configModel() {
    if (params.duty < 0 || params.duty > 1.0) {
        return RSISCmdStat::ERR;
    }

    return RSISCmdStat::OK;
}

RSISCmdStat PWM_Model::initModel() {
    // adjust output for initial phase
    return RSISCmdStat::OK;
}

RSISCmdStat PWM_Model::stepModel() {
    return RSISCmdStat::OK;
}

RSISCmdStat PWM_Model::destroyModel() {
    return RSISCmdStat::OK;
}

void PWM_Model::reflect() {
    Reflect_PWM();
}
