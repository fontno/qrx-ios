import PhotosUI
import QRCore
import SwiftUI

// MARK: - Shape

struct ShapeSectionView: View {
    @Bindable var model: BuilderModel

    var body: some View {
        Section {
            shapeRow(
                title: "Modules",
                items: ModuleShape.allCases,
                selection: $model.design.moduleShape
            ) { shape, color in
                ModuleSwatch(shape: shape, color: color)
            }
            shapeRow(
                title: "Eyes",
                items: EyeShape.allCases,
                selection: $model.design.eyeShape
            ) { shape, color in
                EyeSwatch(shape: shape, color: color)
            }
        }
    }

    @ViewBuilder
    private func shapeRow<S: Identifiable & Equatable>(
        title: String,
        items: [S],
        selection: Binding<S>,
        @ViewBuilder swatch: @escaping (S, Color) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(items) { item in
                    let isSelected = selection.wrappedValue == item
                    Button {
                        selection.wrappedValue = item
                    } label: {
                        swatch(item, isSelected ? Color.primary : Color.primary.opacity(0.55))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Colors

struct ColorsSectionView: View {
    @Bindable var model: BuilderModel

    var body: some View {
        Section {
            ColorPicker("Foreground", selection: Binding(rgba: foregroundBinding), supportsOpacity: false)
            Toggle("Gradient", isOn: $model.isGradient)
            if model.isGradient {
                ColorPicker("Second color", selection: Binding(rgba: secondaryBinding), supportsOpacity: false)
                LabeledContent("Angle") {
                    Slider(value: $model.angleDegrees, in: 0...360, step: 15)
                        .frame(maxWidth: 180)
                }
            }
            ColorPicker("Background", selection: Binding(rgba: $model.design.background), supportsOpacity: true)
            Toggle("Custom eye colors", isOn: $model.hasCustomEyeColors)
            if model.hasCustomEyeColors {
                ColorPicker("Eye ring", selection: Binding(rgba: $model.design.eyeColor, default: model.foregroundColor), supportsOpacity: false)
                ColorPicker("Pupil", selection: Binding(rgba: $model.design.pupilColor, default: model.foregroundColor), supportsOpacity: false)
            }
        }
    }

    private var foregroundBinding: Binding<RGBAColor> {
        Binding(get: { model.foregroundColor }, set: { model.foregroundColor = $0 })
    }

    private var secondaryBinding: Binding<RGBAColor> {
        Binding(get: { model.secondaryColor }, set: { model.secondaryColor = $0 })
    }
}

// MARK: - Frame

struct FrameSectionView: View {
    @Bindable var model: BuilderModel

    var body: some View {
        Section {
            Toggle("\u{201C}Scan me\u{201D} frame", isOn: $model.hasFrame)
            if model.hasFrame {
                Picker("Style", selection: $model.frameLabelEdge) {
                    Text("Banner").tag(QRFrame.LabelEdge.bottom)
                    Text("Top label").tag(QRFrame.LabelEdge.top)
                }
                .pickerStyle(.segmented)
                TextField("Label", text: frameTextBinding)
                    .textInputAutocapitalization(.characters)
                ColorPicker("Frame color", selection: Binding(rgba: frameColorBinding), supportsOpacity: false)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Badge")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    BrandPickerRow(includeNone: true) { brand in
                        model.frameBadgeData = brand?.pngData()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var frameTextBinding: Binding<String> {
        Binding(get: { model.frameText }, set: { model.frameText = $0 })
    }

    private var frameColorBinding: Binding<RGBAColor> {
        Binding(get: { model.frameColor }, set: { model.frameColor = $0 })
    }
}

// MARK: - Logo

struct LogoSectionView: View {
    @Bindable var model: BuilderModel
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Section {
            Picker("Logo", selection: $model.logoSource) {
                ForEach(LogoSource.allCases) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)

            switch model.logoSource {
            case .none:
                EmptyView()
            case .photo:
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        if let data = model.photoLogoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Change photo")
                        } else {
                            Image(systemName: "photo.badge.plus")
                            Text("Choose photo")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or pick a brand")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    BrandPickerRow(includeNone: false) { brand in
                        if let data = brand?.pngData() {
                            model.photoLogoData = data
                            model.syncLogo()
                        }
                    }
                }
                .padding(.vertical, 4)
            case .monogram:
                TextField("Initials (1–2 letters)", text: $model.monogramText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: model.monogramText) { _, newValue in
                        if newValue.count > 2 {
                            model.monogramText = String(newValue.prefix(2))
                        }
                    }
                ColorPicker("Letter color", selection: Binding(rgba: $model.monogramColor), supportsOpacity: false)
                ColorPicker("Badge color", selection: Binding(rgba: $model.monogramBackground), supportsOpacity: false)
            }

            if model.logoSource != .none {
                LabeledContent("Size") {
                    Slider(value: $model.logoSizeFraction, in: 0.12...0.3)
                        .frame(maxWidth: 180)
                }
                Picker("Shape", selection: $model.logoBacking) {
                    ForEach(LogoBacking.allCases) { backing in
                        Text(backing.displayName).tag(backing)
                    }
                }
                Toggle("Clear modules behind logo", isOn: $model.logoKnockout)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    model.photoLogoData = Self.downscaled(data)
                    model.syncLogo()
                }
            }
        }
        .onChange(of: model.logoSource) { model.syncLogo() }
        .onChange(of: model.monogramText) { model.syncLogo() }
        .onChange(of: model.monogramColor) { model.syncLogo() }
        .onChange(of: model.monogramBackground) { model.syncLogo() }
        .onChange(of: model.logoSizeFraction) { model.syncLogo() }
        .onChange(of: model.logoBacking) { model.syncLogo() }
        .onChange(of: model.logoKnockout) { model.syncLogo() }
    }

    /// Keeps embedded logos small: PhotosPicker can hand back multi-MB images.
    private static func downscaled(_ data: Data, maxSide: CGFloat = 600) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return data }
        let scale = maxSide / side
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.pngData() ?? data
    }
}

// MARK: - Swatches

/// Mini 3×3 grid of one module shape.
struct ModuleSwatch: View {
    let shape: ModuleShape
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 3.6
            let inset = (size.width - cell * 3) / 2
            for row in 0..<3 {
                for col in 0..<3 where (row + col) % 2 == 0 {
                    let rect = CGRect(
                        x: inset + CGFloat(col) * cell,
                        y: inset + CGFloat(row) * cell,
                        width: cell, height: cell
                    )
                    context.fill(Path(shape.path(in: rect)), with: .color(color))
                }
            }
        }
        .padding(6)
    }
}

/// Mini eye ring + pupil.
struct EyeSwatch: View {
    let shape: EyeShape
    let color: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
            context.fill(
                Path(shape.ringPath(in: rect, corner: .topLeft)),
                with: .color(color),
                style: FillStyle(eoFill: true)
            )
            context.fill(Path(shape.pupilPath(in: rect, corner: .topLeft)), with: .color(color))
        }
        .padding(4)
    }
}
