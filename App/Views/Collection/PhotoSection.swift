import SwiftUI
import SwiftData
import PhotosUI

struct PhotoSection: View {
    @Environment(\.modelContext) private var context
    let snake: Snake

    @State private var selection: [PhotosPickerItem] = []
    @State private var viewing: SnakePhoto?
    @State private var showingCamera = false
    @State private var importing = false

    private var photos: [SnakePhoto] {
        snake.photos.sorted { $0.dateTaken > $1.dateTaken }
    }

    var body: some View {
        if !photos.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(photos) { photo in
                    Button { viewing = photo } label: {
                        SnakeThumbnail(photo: photo, size: 90)
                            .overlay(alignment: .topTrailing) {
                                if photo.isCover {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .padding(4)
                                        .foregroundStyle(.yellow)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }

        HStack {
            PhotosPicker(selection: $selection, maxSelectionCount: 20, matching: .images) {
                Label("Add Photos", systemImage: "photo.on.rectangle.angled")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Spacer()
                Button { showingCamera = true } label: {
                    Label("Camera", systemImage: "camera")
                }
            }
            if importing {
                Spacer()
                ProgressView()
            }
        }
        .buttonStyle(.borderless)
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            importing = true
            Task { @MainActor in
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let prepared = ImageProcessing.prepare(data) {
                        add(prepared)
                    }
                }
                selection = []
                importing = false
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                if let prepared = ImageProcessing.prepare(image) { add(prepared) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewing) { photo in
            PhotoViewer(photo: photo, snake: snake)
        }
    }

    private func add(_ prepared: (image: Data, thumbnail: Data)) {
        let photo = SnakePhoto(imageData: prepared.image, thumbnailData: prepared.thumbnail)
        context.insert(photo)
        photo.snake = snake
    }
}

struct PhotoViewer: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var photo: SnakePhoto
    let snake: Snake

    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            VStack {
                if let image = UIImage(data: photo.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(MagnifyGesture().onChanged { scale = max(1, $0.magnification) }
                                                 .onEnded { _ in withAnimation { scale = 1 } })
                        .frame(maxHeight: .infinity)
                }
                Form {
                    TextField("Caption", text: $photo.caption)
                    DatePicker("Taken", selection: $photo.dateTaken, displayedComponents: .date)
                }
                .frame(height: 140)
            }
            .navigationTitle(snake.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        for other in snake.photos { other.isCover = false }
                        photo.isCover = true
                    } label: {
                        Label("Set as Cover", systemImage: photo.isCover ? "star.fill" : "star")
                    }
                    Spacer()
                    if let image = UIImage(data: photo.imageData) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(snake.name, image: Image(uiImage: image)))
                    }
                    Spacer()
                    Button(role: .destructive) {
                        context.delete(photo)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Minimal camera wrapper; PhotosPicker covers the library.
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
