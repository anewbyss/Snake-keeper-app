import SwiftUI
import SwiftData
import PhotosUI

/// Profile row for the top of Settings.
struct ProfileRow: View {
    @Query private var profiles: [BreederProfile]

    var body: some View {
        let profile = profiles.first
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: 12) {
                ProfilePhoto(data: profile?.photoData, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.displayName.isEmpty == false ? profile!.displayName : "Your Profile").font(.headline)
                    Text(profile?.location.isEmpty == false ? profile!.location : "Breeder name, contact details and defaults")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ProfilePhoto: View {
    let data: Data?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
                    .foregroundStyle(.secondary)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [BreederProfile]
    @Query private var snakes: [Snake]
    @Query private var pairings: [Pairing]
    @State private var editing: BreederProfile?

    var body: some View {
        let profile = profiles.first
        List {
            Section {
                HStack(spacing: 16) {
                    ProfilePhoto(data: profile?.photoData, size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.displayName.isEmpty == false ? profile!.displayName : "Add your details").font(.headline)
                        if let profile, !profile.business.isEmpty, !profile.name.isEmpty {
                            Text(profile.name).foregroundStyle(.secondary)
                        }
                        if let location = profile?.location, !location.isEmpty {
                            Text(location).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            if let profile {
                Section("Contact") {
                    if !profile.email.isEmpty, let url = URL(string: "mailto:\(profile.email)") {
                        Link(destination: url) { LabeledContent("Email", value: profile.email) }
                    }
                    if !profile.phone.isEmpty, let url = phoneURL(profile.phone) {
                        Link(destination: url) { LabeledContent("Phone", value: profile.phone) }
                    }
                    if !profile.website.isEmpty,
                       let url = URL(string: profile.website.contains("://") ? profile.website : "https://\(profile.website)") {
                        Link(destination: url) { LabeledContent("Website", value: profile.website) }
                    }
                    if !profile.social.isEmpty {
                        LabeledContent("Social", value: profile.social)
                    }
                    if profile.email.isEmpty && profile.phone.isEmpty && profile.website.isEmpty && profile.social.isEmpty {
                        Text("No contact details yet.").foregroundStyle(.secondary)
                    }
                }
                Section("Defaults") {
                    LabeledContent("Species for new snakes", value: profile.defaultSpecies)
                    LabeledContent("Feeding interval", value: "\(profile.defaultFeedingInterval) days")
                }
            }
            Section("At a Glance") {
                LabeledContent("In collection", value: "\(snakes.filter(\.isInCollection).count)")
                LabeledContent("For sale", value: "\(snakes.filter { $0.status == .forSale }.count)")
                LabeledContent("Bred by you", value: "\(snakes.filter { $0.origin == .homeBred }.count)")
                LabeledContent("Active pairings", value: "\(pairings.filter { $0.status.isActive }.count)")
            }
            if let notes = profile?.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
            Section {
            } footer: {
                Text("Your name appears on exports and as the default for snakes you breed. The profile syncs with the web app.")
            }
        }
        .navigationTitle("Profile")
        .toolbar { Button("Edit") { editing = BreederProfile.current(in: context) } }
        .sheet(item: $editing) { profile in
            NavigationStack { ProfileEditView(profile: profile) }
        }
    }

    private func phoneURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return URL(string: "tel:" + digits)
    }
}

struct ProfileEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customGenes: [CustomGene]

    let profile: BreederProfile

    @State private var name: String
    @State private var business: String
    @State private var location: String
    @State private var email: String
    @State private var phone: String
    @State private var website: String
    @State private var social: String
    @State private var photoData: Data?
    @State private var defaultSpecies: String
    @State private var defaultFeedingInterval: Int
    @State private var notes: String
    @State private var photoItem: PhotosPickerItem?

    init(profile: BreederProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _business = State(initialValue: profile.business)
        _location = State(initialValue: profile.location)
        _email = State(initialValue: profile.email)
        _phone = State(initialValue: profile.phone)
        _website = State(initialValue: profile.website)
        _social = State(initialValue: profile.social)
        _photoData = State(initialValue: profile.photoData)
        _defaultSpecies = State(initialValue: profile.defaultSpecies)
        _defaultFeedingInterval = State(initialValue: profile.defaultFeedingInterval)
        _notes = State(initialValue: profile.notes)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    ProfilePhoto(data: photoData, size: 64)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("Choose Photo / Logo")
                    }
                    if photoData != nil {
                        Spacer()
                        Button("Remove", role: .destructive) { photoData = nil }
                    }
                }
                .buttonStyle(.borderless)
            }
            Section("Breeder") {
                TextField("Your name", text: $name).textContentType(.name)
                TextField("Business (optional)", text: $business).textContentType(.organizationName)
                TextField("Location (city, state / country)", text: $location)
            }
            Section("Contact") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Phone", text: $phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                TextField("Website", text: $website)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                TextField("Social (@handle, MorphMarket store…)", text: $social)
                    .textInputAutocapitalization(.never)
            }
            Section("Defaults") {
                Picker("Species", selection: $defaultSpecies) {
                    ForEach(GeneCatalog(custom: customGenes).speciesNames, id: \.self) { Text($0).tag($0) }
                }
                Stepper("Feed every \(defaultFeedingInterval) days", value: $defaultFeedingInterval, in: 1...60)
            }
            Section("Notes") {
                TextField("Permits, policies, anything else", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let prepared = ImageProcessing.prepare(image, maxDimension: 600) {
                    photoData = prepared
                }
                photoItem = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
    }

    private func save() {
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        profile.name = trim(name)
        profile.business = trim(business)
        profile.location = trim(location)
        profile.email = trim(email)
        profile.phone = trim(phone)
        profile.website = trim(website)
        profile.social = trim(social)
        profile.photoData = photoData
        profile.defaultSpecies = defaultSpecies
        profile.defaultFeedingInterval = defaultFeedingInterval
        profile.notes = notes
        context.saveNow()
        dismiss()
    }
}
