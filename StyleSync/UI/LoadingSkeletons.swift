import SwiftUI

struct SkeletonView: View {
    let cornerRadius: CGFloat
    let height: CGFloat?
    let animation: Animation

    @State private var shimmerOffset: CGFloat = -200

    init(
        cornerRadius: CGFloat = 8,
        height: CGFloat? = nil,
        animation: Animation = .linear(duration: 1.5).repeatForever(autoreverses: false)
    ) {
        self.cornerRadius = cornerRadius
        self.height = height
        self.animation = animation
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.3),
                                .white.opacity(0.5),
                                .white.opacity(0.3),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .clipped()
            )
            .clipped()
            .onAppear {
                withAnimation(animation) {
                    shimmerOffset = 200
                }
            }
    }
}

struct OutfitCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(cornerRadius: 12, height: 180)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(cornerRadius: 4, height: 16)
                    .frame(width: 120)

                SkeletonView(cornerRadius: 4, height: 12)
                    .frame(width: 80)

                HStack(spacing: 6) {
                    SkeletonView(cornerRadius: 3, height: 8)
                        .frame(width: 40)
                    SkeletonView(cornerRadius: 3, height: 8)
                        .frame(width: 50)
                    SkeletonView(cornerRadius: 3, height: 8)
                        .frame(width: 35)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(cornerRadius: 25)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(cornerRadius: 4, height: 16)
                    .frame(width: 100)

                SkeletonView(cornerRadius: 4, height: 12)
                    .frame(width: 140)

                HStack(spacing: 8) {
                    SkeletonView(cornerRadius: 2, height: 10)
                        .frame(width: 30)
                    SkeletonView(cornerRadius: 2, height: 10)
                        .frame(width: 45)
                }
            }

            Spacer()

            SkeletonView(cornerRadius: 8, height: 32)
                .frame(width: 80)
        }
        .padding()
    }
}

struct WardrobeGridSkeleton: View {
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                OutfitCardSkeleton()
            }
        }
        .padding(.horizontal)
    }
}

struct TrendingOutfitsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SkeletonView(cornerRadius: 4, height: 20)
                    .frame(width: 140)
                Spacer()
                SkeletonView(cornerRadius: 6, height: 16)
                    .frame(width: 60)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonView(cornerRadius: 12, height: 120)
                                .frame(width: 160)

                            SkeletonView(cornerRadius: 4, height: 12)
                                .frame(width: 100)

                            HStack {
                                SkeletonView(cornerRadius: 8)
                                    .frame(width: 16, height: 16)

                                SkeletonView(cornerRadius: 2, height: 10)
                                    .frame(width: 40)

                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct StyleTipSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonView(cornerRadius: 4, height: 14)
                    .frame(width: 80)

                Spacer()

                SkeletonView(cornerRadius: 12)
                    .frame(width: 24, height: 24)
            }

            SkeletonView(cornerRadius: 4, height: 18)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(cornerRadius: 3, height: 12)
                    .frame(maxWidth: .infinity)

                SkeletonView(cornerRadius: 3, height: 12)
                    .frame(width: 240)

                SkeletonView(cornerRadius: 3, height: 12)
                    .frame(width: 180)
            }

            HStack {
                SkeletonView(cornerRadius: 12, height: 20)
                    .frame(width: 50)

                SkeletonView(cornerRadius: 12, height: 20)
                    .frame(width: 70)

                Spacer()

                SkeletonView(cornerRadius: 10)
                    .frame(width: 20, height: 20)

                SkeletonView(cornerRadius: 10)
                    .frame(width: 20, height: 20)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WeatherWidgetSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(cornerRadius: 3, height: 10)
                        .frame(width: 80)

                    SkeletonView(cornerRadius: 4, height: 16)
                        .frame(width: 120)
                }

                Spacer()

                SkeletonView(cornerRadius: 20)
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 8) {
                SkeletonView(cornerRadius: 4, height: 12)
                    .frame(width: 140)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 4) {
                            SkeletonView(cornerRadius: 6, height: 30)

                            SkeletonView(cornerRadius: 2, height: 8)
                                .frame(width: 40)
                        }
                    }
                }
            }

            HStack {
                SkeletonView(cornerRadius: 8, height: 24)
                    .frame(width: 60)

                Spacer()

                SkeletonView(cornerRadius: 2, height: 10)
                    .frame(width: 100)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct AnalyticsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SkeletonView(cornerRadius: 4, height: 18)
                    .frame(width: 120)

                Spacer()

                SkeletonView(cornerRadius: 8, height: 16)
                    .frame(width: 80)
            }

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(cornerRadius: 3, height: 10)
                            .frame(width: 60)

                        SkeletonView(cornerRadius: 4, height: 24)
                            .frame(width: 40)

                        SkeletonView(cornerRadius: 2, height: 8)
                            .frame(width: 50)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(cornerRadius: 3, height: 10)
                            .frame(width: 80)

                        SkeletonView(cornerRadius: 4, height: 24)
                            .frame(width: 50)

                        SkeletonView(cornerRadius: 2, height: 8)
                            .frame(width: 70)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SkeletonView(cornerRadius: 3, height: 12)
                        .frame(width: 100)

                    SkeletonView(cornerRadius: 8, height: 120)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(0..<7, id: \.self) { _ in
                                        SkeletonView(cornerRadius: 1)
                                            .frame(width: 4, height: CGFloat.random(in: 20...60))
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        )
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 12) {
                SkeletonView(cornerRadius: 3, height: 12)
                    .frame(width: 140)

                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            SkeletonView(cornerRadius: 4)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                SkeletonView(cornerRadius: 3, height: 12)
                                    .frame(width: 100)

                                SkeletonView(cornerRadius: 2, height: 8)
                                    .frame(width: 160)
                            }

                            Spacer()

                            SkeletonView(cornerRadius: 2, height: 10)
                                .frame(width: 30)
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

struct PulsingDots: View {
    @State private var animateFirstDot = false
    @State private var animateSecondDot = false
    @State private var animateThirdDot = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.gray.opacity(0.4))
                .frame(width: 8, height: 8)
                .scaleEffect(animateFirstDot ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                    value: animateFirstDot
                )

            Circle()
                .fill(.gray.opacity(0.4))
                .frame(width: 8, height: 8)
                .scaleEffect(animateSecondDot ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.2),
                    value: animateSecondDot
                )

            Circle()
                .fill(.gray.opacity(0.4))
                .frame(width: 8, height: 8)
                .scaleEffect(animateThirdDot ? 1.2 : 0.8)
                .animation(
                    .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.4),
                    value: animateThirdDot
                )
        }
        .onAppear {
            animateFirstDot = true
            animateSecondDot = true
            animateThirdDot = true
        }
    }
}

struct WaveLoader: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.blue.gradient)
                    .frame(width: 4, height: 20)
                    .scaleEffect(y: animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct CircularProgress: View {
    @State private var progress: Double = 0
    let lineWidth: CGFloat

    init(lineWidth: CGFloat = 4) {
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    .blue.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                    .repeatForever(autoreverses: false)
            ) {
                progress = 1.0
            }
        }
    }
}

struct SkeletonModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .shimmer()
        } else {
            content
        }
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }
}

struct LoadingStateShowcase: View {
    @State private var selectedType = 0

    var body: some View {
        VStack(spacing: 20) {
            Picker("Loading Type", selection: $selectedType) {
                Text("Cards").tag(0)
                Text("Profile").tag(1)
                Text("Analytics").tag(2)
                Text("Loaders").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())

            ScrollView {
                Group {
                    switch selectedType {
                    case 0:
                        VStack(spacing: 16) {
                            OutfitCardSkeleton()
                            TrendingOutfitsSkeleton()
                            StyleTipSkeleton()
                        }

                    case 1:
                        VStack(spacing: 16) {
                            ProfileSkeleton()
                            WeatherWidgetSkeleton()
                        }

                    case 2:
                        AnalyticsSkeleton()

                    case 3:
                        VStack(spacing: 30) {
                            PulsingDots()

                            WaveLoader()

                            CircularProgress()
                                .frame(width: 50, height: 50)

                            HStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(0.8)

                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                        }

                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}