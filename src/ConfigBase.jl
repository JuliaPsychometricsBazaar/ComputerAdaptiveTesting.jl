module ConfigBase

export CatConfigBase

abstract type CatConfigBase end

# Trait pattern (This block may be heading for the bin)
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