import Foundation

/// A typed, persisted preference: where it lives in `UserDefaults` and how a raw stored value
/// becomes a valid `Value`. `decode` is total — a missing or invalid stored value yields the
/// default (or a normalized value) — so loading a setting never needs a fallback at the call
/// site, and every setting is read and written through the same pair of functions.
///
/// Domain files declare their keys as static properties in constrained extensions, so call sites
/// read `defaults.value(for: .launchAtLogin)` and the type is inferred from the property.
struct SettingKey<Value: Sendable>: Sendable {
    let name: String
    let decode: @Sendable (Any?) -> Value
    let encode: @Sendable (Value) -> Any

    init(
        _ name: String,
        decode: @escaping @Sendable (Any?) -> Value,
        encode: @escaping @Sendable (Value) -> Any
    ) {
        self.name = name
        self.decode = decode
        self.encode = encode
    }

    /// The value as it would be read back from storage: out-of-range input clamped, invalid input
    /// replaced by the default.
    func sanitized(_ value: Value) -> Value {
        decode(encode(value))
    }
}

extension SettingKey where Value == Bool {
    static func bool(_ name: String, default defaultValue: Bool) -> Self {
        Self(name, decode: { $0 as? Bool ?? defaultValue }, encode: { $0 })
    }
}

extension SettingKey where Value == Double {
    static func double(
        _ name: String,
        default defaultValue: Double,
        normalize: @escaping @Sendable (Double) -> Double = { $0 }
    ) -> Self {
        Self(name, decode: { normalize($0 as? Double ?? defaultValue) }, encode: { $0 })
    }
}

extension SettingKey where Value: RawRepresentable, Value.RawValue == String {
    static func stringEnum(_ name: String, default defaultValue: Value) -> Self {
        Self(
            name,
            decode: { ($0 as? String).flatMap(Value.init(rawValue:)) ?? defaultValue },
            encode: { $0.rawValue }
        )
    }

    /// For enums that own their own fallback rules (`normalized(rawValue:)`).
    static func stringEnum(
        _ name: String,
        normalize: @escaping @Sendable (String?) -> Value
    ) -> Self {
        Self(name, decode: { normalize($0 as? String) }, encode: { $0.rawValue })
    }
}

extension SettingKey where Value: RawRepresentable, Value.RawValue == Int {
    static func intEnum(_ name: String, default defaultValue: Value) -> Self {
        Self(
            name,
            decode: { ($0 as? Int).flatMap(Value.init(rawValue:)) ?? defaultValue },
            encode: { $0.rawValue }
        )
    }
}

extension UserDefaults {
    func value<Value>(for key: SettingKey<Value>) -> Value {
        key.decode(object(forKey: key.name))
    }

    func store<Value>(_ value: Value, for key: SettingKey<Value>) {
        set(key.encode(value), forKey: key.name)
    }

    /// The raw stored value, for one-time migrations that must look at what is on disk
    /// before it is normalized.
    func storedObject<Value>(for key: SettingKey<Value>) -> Any? {
        object(forKey: key.name)
    }
}
