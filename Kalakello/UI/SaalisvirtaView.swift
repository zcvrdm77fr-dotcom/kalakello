import PhotosUI
import SwiftUI
import UIKit

struct SaalisvirtaView: View {
    @State private var posts: [CommunityPost] = []
    @State private var user: CommunityUser?
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var caption = ""
    @State private var commentDrafts: [Int: String] = [:]
    @State private var expandedComments: Set<Int> = []
    @State private var commentsByPost: [Int: [CommunityComment]] = [:]
    @State private var busy = false
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if user == nil {
                    signInView
                } else {
                    feedView
                }
            }
            .navigationTitle("Saalisvirta")
            .toolbar {
                if let user {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Text("Kirjautunut: \(user.username)")
                            Button("Kirjaudu ulos", role: .destructive) { Task { await logout() } }
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
            }
            .task { await refreshSession() }
            .refreshable { await reloadFeed() }
            .alert("Saalisvirta", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var signInView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.accent)
                Text("Jaa saaliisi").font(.title2.bold())
                Text("Kirjaudu FastFishing-tililläsi tai luo tili. Julkaisut näkyvät samalla sekä sovelluksessa että FastFishing.comissa.")
                    .foregroundStyle(.secondary)
                TextField("Käyttäjänimi", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                SecureField("Salasana", text: $password)
                    .textContentType(isSigningUp ? .newPassword : .password)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await authenticate() }
                } label: {
                    HStack {
                        if busy { ProgressView().tint(.black) }
                        Text(isSigningUp ? "Luo tili" : "Kirjaudu sisään")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(busy || username.isEmpty || password.isEmpty)
                Button(isSigningUp ? "Minulla on jo tili" : "Luo uusi tili") {
                    isSigningUp.toggle()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }

    private var feedView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                publishCard
                if loading && posts.isEmpty {
                    ProgressView("Ladataan saaliita…").padding(32)
                } else if posts.isEmpty {
                    ContentUnavailableView("Ei vielä julkaisuja", systemImage: "fish", description: Text("Ole ensimmäinen ja jaa saaliisi."))
                        .padding(.top, 24)
                } else {
                    ForEach(posts) { post in
                        postCard(post)
                    }
                }
                Button("Päivitä Saalisvirta") { Task { await reloadFeed() } }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
    }

    private var publishCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Uusi saalis").font(.headline)
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: photoData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                    Text(photoData == nil ? "Valitse saaliskuva" : "Kuva valittu – vaihda kuva")
                    Spacer()
                }
                .padding(12)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else {
                        photoData = nil
                        return
                    }
                    photoData = UIImage(data: data)?.jpegData(compressionQuality: 0.82) ?? data
                }
            }
            TextField("Kerro saaliista (valinnainen)", text: $caption, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await publish() }
            } label: {
                HStack {
                    if busy { ProgressView().tint(.black) }
                    Label("Julkaise Saalisvirtaan", systemImage: "paperplane.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(busy || photoData == nil)
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func postCard(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.username).font(.headline)
                    Text(post.createdAt ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let url = post.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: imagePlaceholder
                    case .empty: ProgressView().frame(maxWidth: .infinity).frame(height: 180)
                    @unknown default: imagePlaceholder
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let caption = post.caption, !caption.isEmpty { Text(caption) }
            let details = [
                post.species,
                post.weightKg.map { String(format: "%.2f kg", $0) },
                post.lengthCm.map { String(format: "%.1f cm", $0) },
                post.lure.map { "Viehe: \($0)" },
                post.catchLocation.map { "Paikka: \($0)" }
            ].compactMap { $0 }
            if !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                Button {
                    Task { await toggleLike(post) }
                } label: {
                    Label("\(post.likeCount)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                        .foregroundStyle(post.likedByMe ? .red : .primary)
                }
                .disabled(busy)
                Button {
                    Task { await toggleComments(post) }
                } label: {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                }
                Spacer()
            }
            if expandedComments.contains(post.id) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(commentsByPost[post.id] ?? []) { comment in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(comment.username).font(.caption.bold())
                            Text(comment.body).font(.subheadline)
                        }
                    }
                    HStack {
                        TextField("Kirjoita kommentti…", text: Binding(
                            get: { commentDrafts[post.id, default: ""] },
                            set: { commentDrafts[post.id] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        Button {
                            Task { await sendComment(post) }
                        } label: { Image(systemName: "paperplane.fill") }
                        .disabled((commentDrafts[post.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.06))
            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            .frame(height: 180)
    }

    private func refreshSession() async {
        do {
            user = try await CommunityAPI.shared.currentUser()
            if user != nil { await reloadFeed() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate() async {
        busy = true
        defer { busy = false }
        do {
            if isSigningUp {
                _ = try await CommunityAPI.shared.signup(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            } else {
                _ = try await CommunityAPI.shared.login(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            }
            user = try await CommunityAPI.shared.currentUser()
            password = ""
            await reloadFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logout() async {
        do { try await CommunityAPI.shared.logout() }
        catch { errorMessage = error.localizedDescription }
        user = nil
        posts = []
    }

    private func reloadFeed() async {
        loading = true
        defer { loading = false }
        do { posts = try await CommunityAPI.shared.feed() }
        catch { errorMessage = error.localizedDescription }
    }

    private func publish() async {
        guard let photoData else { return }
        busy = true
        defer { busy = false }
        do {
            try await CommunityAPI.shared.publish(imageData: photoData, caption: caption.trimmingCharacters(in: .whitespacesAndNewlines))
            self.photoData = nil
            selectedPhoto = nil
            caption = ""
            await reloadFeed()
        } catch { errorMessage = error.localizedDescription }
    }

    private func toggleLike(_ post: CommunityPost) async {
        busy = true
        defer { busy = false }
        do {
            let result = try await CommunityAPI.shared.toggleLike(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].likedByMe = result.liked
                posts[index].likeCount = result.likeCount
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func toggleComments(_ post: CommunityPost) async {
        if expandedComments.contains(post.id) {
            expandedComments.remove(post.id)
            return
        }
        do {
            commentsByPost[post.id] = try await CommunityAPI.shared.comments(postID: post.id)
            expandedComments.insert(post.id)
        } catch { errorMessage = error.localizedDescription }
    }

    private func sendComment(_ post: CommunityPost) async {
        let text = (commentDrafts[post.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let comment = try await CommunityAPI.shared.addComment(postID: post.id, body: text)
            commentsByPost[post.id, default: []].append(comment)
            commentDrafts[post.id] = ""
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].commentCount += 1
            }
        } catch { errorMessage = error.localizedDescription }
    }
}
