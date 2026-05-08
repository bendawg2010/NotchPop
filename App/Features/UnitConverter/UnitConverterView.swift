// UnitConverterView.swift
//
// Pane shown inside the expanded notch when the Unit Converter tab
// is active. Picks a category (length / mass / temperature / volume
// / time / data), enter a value, see all the conversions
// instantly. No internet required — all conversions are local. The
// last-used category and value persist so reopening the tab brings
// you back where you left off.

import SwiftUI

private struct UnitDef: Identifiable {
    let id: String
    let label: String
    let symbol: String
    /// Multiplier to convert FROM this unit INTO the category's
    /// base unit. Temperature is special-cased separately because
    /// it isn't a pure ratio.
    let toBase: Double
}

private struct CategoryDef: Identifiable {
    let id: String
    let label: String
    let icon: String
    let units: [UnitDef]
    /// True for temperature — uses convertTemperature() instead of
    /// the linear toBase × value math.
    let isTemperature: Bool
}

private let kCategories: [CategoryDef] = [
    CategoryDef(id: "length", label: "Length", icon: "ruler.fill",
                units: [
                    UnitDef(id: "mm", label: "Millimeter", symbol: "mm", toBase: 0.001),
                    UnitDef(id: "cm", label: "Centimeter", symbol: "cm", toBase: 0.01),
                    UnitDef(id: "m",  label: "Meter",      symbol: "m",  toBase: 1.0),
                    UnitDef(id: "km", label: "Kilometer",  symbol: "km", toBase: 1000.0),
                    UnitDef(id: "in", label: "Inch",       symbol: "in", toBase: 0.0254),
                    UnitDef(id: "ft", label: "Foot",       symbol: "ft", toBase: 0.3048),
                    UnitDef(id: "yd", label: "Yard",       symbol: "yd", toBase: 0.9144),
                    UnitDef(id: "mi", label: "Mile",       symbol: "mi", toBase: 1609.344),
                ],
                isTemperature: false),
    CategoryDef(id: "mass", label: "Mass", icon: "scalemass.fill",
                units: [
                    UnitDef(id: "mg", label: "Milligram",  symbol: "mg", toBase: 0.000001),
                    UnitDef(id: "g",  label: "Gram",       symbol: "g",  toBase: 0.001),
                    UnitDef(id: "kg", label: "Kilogram",   symbol: "kg", toBase: 1.0),
                    UnitDef(id: "oz", label: "Ounce",      symbol: "oz", toBase: 0.0283495),
                    UnitDef(id: "lb", label: "Pound",      symbol: "lb", toBase: 0.4535924),
                ],
                isTemperature: false),
    CategoryDef(id: "temp", label: "Temp", icon: "thermometer.medium",
                units: [
                    UnitDef(id: "C", label: "Celsius",    symbol: "°C", toBase: 0),
                    UnitDef(id: "F", label: "Fahrenheit", symbol: "°F", toBase: 0),
                    UnitDef(id: "K", label: "Kelvin",     symbol: "K",  toBase: 0),
                ],
                isTemperature: true),
    CategoryDef(id: "volume", label: "Volume", icon: "cube.fill",
                units: [
                    UnitDef(id: "ml",   label: "Milliliter", symbol: "ml",  toBase: 0.001),
                    UnitDef(id: "l",    label: "Liter",      symbol: "L",   toBase: 1.0),
                    UnitDef(id: "tsp",  label: "Teaspoon",   symbol: "tsp", toBase: 0.00492892),
                    UnitDef(id: "tbsp", label: "Tablespoon", symbol: "tbsp", toBase: 0.0147868),
                    UnitDef(id: "cup",  label: "Cup (US)",   symbol: "cup", toBase: 0.236588),
                    UnitDef(id: "pt",   label: "Pint (US)",  symbol: "pt",  toBase: 0.473176),
                    UnitDef(id: "gal",  label: "Gallon",     symbol: "gal", toBase: 3.78541),
                ],
                isTemperature: false),
    CategoryDef(id: "data", label: "Data", icon: "externaldrive.fill",
                units: [
                    UnitDef(id: "B",  label: "Byte",     symbol: "B",  toBase: 1.0),
                    UnitDef(id: "KB", label: "Kilobyte", symbol: "KB", toBase: 1024.0),
                    UnitDef(id: "MB", label: "Megabyte", symbol: "MB", toBase: 1048576.0),
                    UnitDef(id: "GB", label: "Gigabyte", symbol: "GB", toBase: 1073741824.0),
                    UnitDef(id: "TB", label: "Terabyte", symbol: "TB", toBase: 1099511627776.0),
                ],
                isTemperature: false),
]

struct UnitConverterView: View {
    @State private var categoryID: String = UserDefaults.standard.string(forKey: "np.unit.cat") ?? "length"
    @State private var fromUnitID: String = UserDefaults.standard.string(forKey: "np.unit.from") ?? "m"
    @State private var input: String = UserDefaults.standard.string(forKey: "np.unit.val") ?? "1"
    @FocusState private var inputFocused: Bool

    private var currentCategory: CategoryDef {
        kCategories.first(where: { $0.id == categoryID }) ?? kCategories[0]
    }
    private var fromUnit: UnitDef {
        currentCategory.units.first(where: { $0.id == fromUnitID }) ?? currentCategory.units[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(kCategories) { c in
                    Button {
                        categoryID = c.id
                        if !c.units.contains(where: { $0.id == fromUnitID }) {
                            fromUnitID = c.units[0].id
                        }
                        UserDefaults.standard.set(c.id, forKey: "np.unit.cat")
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: c.icon).font(.system(size: 9))
                            Text(c.label).font(.system(size: 9, weight: .heavy))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(c.id == categoryID
                                      ? Color.white.opacity(0.18)
                                      : Color.white.opacity(0.06))
                        )
                        .foregroundColor(.white.opacity(c.id == categoryID ? 1.0 : 0.62))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                TextField("1", text: $input)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 8)
                    .frame(width: 80, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.10))
                    )
                    .onChange(of: input) { v in
                        UserDefaults.standard.set(v, forKey: "np.unit.val")
                    }
                Picker("", selection: $fromUnitID) {
                    ForEach(currentCategory.units) { u in
                        Text(u.symbol).tag(u.id)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
                .onChange(of: fromUnitID) { v in
                    UserDefaults.standard.set(v, forKey: "np.unit.from")
                }
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(otherUnits()) { u in
                            VStack(spacing: 0) {
                                Text(formattedConversion(to: u))
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(u.symbol)
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func otherUnits() -> [UnitDef] {
        currentCategory.units.filter { $0.id != fromUnitID }
    }

    private func formattedConversion(to: UnitDef) -> String {
        let value = Double(input) ?? 0
        let result: Double
        if currentCategory.isTemperature {
            result = convertTemperature(value, from: fromUnit.id, to: to.id)
        } else {
            let base = value * fromUnit.toBase
            result = base / to.toBase
        }
        if abs(result) >= 100 {
            return String(format: "%.1f", result)
        } else if abs(result) >= 1 {
            return String(format: "%.2f", result)
        } else {
            return String(format: "%.4g", result)
        }
    }

    private func convertTemperature(_ v: Double, from: String, to: String) -> Double {
        // Convert to Celsius first, then out to target.
        let celsius: Double
        switch from {
        case "F": celsius = (v - 32) * 5.0 / 9.0
        case "K": celsius = v - 273.15
        default:  celsius = v
        }
        switch to {
        case "F": return celsius * 9.0 / 5.0 + 32
        case "K": return celsius + 273.15
        default:  return celsius
        }
    }
}
