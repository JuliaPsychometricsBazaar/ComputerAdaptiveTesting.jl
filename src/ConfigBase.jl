module ConfigBase

abstract type CatConfigBase end

# Trait pattern
abstract type ConfigPurity end
ConfigPurity(config::CatConfigBase) = ConfigPurity(typeof(config))
struct PureConfig <: ConfigPurity end
struct ImpureConfig <: ConfigPurity end

@inline function (self::CatConfigBase)()
    self(ConfigPurity(self))
end

@inline function (self::CatConfigBase)(::Type{PureConfig})
    self
end

end