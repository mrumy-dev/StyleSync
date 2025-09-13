import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var privacyManager = PrivacyManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @State private var searchText = ""
    @State private var showingUnblockConfirmation = false
    @State private var userToUnblock: String?
    @State private var showingRestrictedUsers = false

    private var filteredBlockedUsers: [String] {
        if searchText.isEmpty {
            return Array(privacyManager.blockedUsers)
        } else {
            return Array(privacyManager.blockedUsers).filter { userID in
                let profile = profileManager.getProfile(userID)
                return profile?.displayName.localizedCaseInsensitiveContains(searchText) == true ||
                       profile?.username.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    private var filteredRestrictedUsers: [String] {
        if searchText.isEmpty {
            return Array(privacyManager.restrictedUsers)
        } else {
            return Array(privacyManager.restrictedUsers).filter { userID in
                let profile = profileManager.getProfile(userID)
                return profile?.displayName.localizedCaseInsensitiveContains(searchText) == true ||
                       profile?.username.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                segmentedControl

                if showingRestrictedUsers {
                    restrictedUsersList
                } else {
                    blockedUsersList
                }

                if privacyManager.blockedUsers.isEmpty && privacyManager.restrictedUsers.isEmpty {
                    emptyStateView
                }
            }
            .background(Color.black)
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Unblock User",
                isPresented: $showingUnblockConfirmation,
                presenting: userToUnblock
            ) { userID in
                Button("Unblock", role: .destructive) {
                    privacyManager.unblockUser(userID)
                }
                Button("Cancel", role: .cancel) { }
            } message: { userID in
                if let profile = profileManager.getProfile(userID) {
                    Text("Are you sure you want to unblock @\(profile.username)? They will be able to see your content and message you again.")
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))

                TextField("Search blocked users", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            Button(action: {
                showingRestrictedUsers = false
                HapticManager.shared.impact(.light)
            }) {
                VStack(spacing: 8) {
                    Text("Blocked")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(showingRestrictedUsers ? .gray : .white)

                    Text("\(privacyManager.blockedUsers.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showingRestrictedUsers ? .gray : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(showingRestrictedUsers ? Color.clear : Color.white.opacity(0.2))
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Button(action: {
                showingRestrictedUsers = true
                HapticManager.shared.impact(.light)
            }) {
                VStack(spacing: 8) {
                    Text("Restricted")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(showingRestrictedUsers ? .white : .gray)

                    Text("\(privacyManager.restrictedUsers.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showingRestrictedUsers ? .white : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(showingRestrictedUsers ? Color.white.opacity(0.2) : Color.clear)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var blockedUsersList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredBlockedUsers, id: \.self) { userID in
                    BlockedUserRow(
                        userID: userID,
                        isRestricted: false,
                        onUnblock: {
                            userToUnblock = userID
                            showingUnblockConfirmation = true
                        },
                        onRestrict: {
                            privacyManager.unblockUser(userID)
                            privacyManager.restrictUser(userID)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var restrictedUsersList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredRestrictedUsers, id: \.self) { userID in
                    BlockedUserRow(
                        userID: userID,
                        isRestricted: true,
                        onUnblock: {
                            privacyManager.unrestrict(userID)
                        },
                        onRestrict: {
                            privacyManager.unrestrict(userID)
                            Task {
                                await privacyManager.blockUser(userID)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: showingRestrictedUsers ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.xmark")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text(showingRestrictedUsers ? "No Restricted Users" : "No Blocked Users")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text(showingRestrictedUsers
                     ? "Users you restrict can still see your public content but won't see when you're active or when you've read their messages."
                     : "Users you block won't be able to see your profile, posts, or message you.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

struct BlockedUserRow: View {
    let userID: String
    let isRestricted: Bool
    let onUnblock: () -> Void
    let onRestrict: () -> Void

    @StateObject private var profileManager = ProfileManager.shared

    private var profile: UserProfile? {
        profileManager.getProfile(userID)
    }

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: profile?.profileImageData.flatMap { URL(string: "data:image/jpeg;base64,\(Data($0).base64EncodedString())") }) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? "Unknown User")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("@\(profile?.username ?? userID)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                if isRestricted {
                    Text("Restricted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                        )
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: onUnblock) {
                    Text(isRestricted ? "Unrestrict" : "Unblock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .hapticFeedback(.light, trigger: true)

                if !isRestricted {
                    Button(action: onRestrict) {
                        Text("Restrict")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .hapticFeedback(.light, trigger: true)
                } else {
                    Button(action: onRestrict) {
                        Text("Block")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .hapticFeedback(.light, trigger: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    BlockedUsersView()
        .preferredColorScheme(.dark)
}