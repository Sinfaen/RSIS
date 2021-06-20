
Base.@kwdef mutable struct PWMIn
    # nothing to see here
end

Base.@kwdef mutable struct PWMOut
    pwm::Port = Port(Float64, (), 0.0; note="PWM signal")
end

Base.@kwdef mutable struct PWMData
    counter::Port = Port(Float64, (), 0.0; note="Counter used for calculating duty")
end

Base.@kwdef mutable struct PWMParams
    period::Port = Port(Float64, (), 1.0; note="Period")
    duty::Port   = Port(Float64, (), 0.5; note="Duty Cycle")
    initial_phase::Port = Port(Int64, (), 0, note="Phase offset")
end

Base.@kwdef mutable struct PWM
    in::PWMIn         = PWMIn()
    out::PWMOut       = PWMOut()
    data::PWMData     = PWMData()
    params::PWMParams = PWMParams()
end
