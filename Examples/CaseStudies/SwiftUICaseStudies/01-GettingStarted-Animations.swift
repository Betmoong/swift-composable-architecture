import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 애플리케이션 상태의 변경이 어떻게 애니메이션을 구동할 수 있는지 보여줍니다. Store는 전송된 액션을 동기적으로 처리하기 때문에, \
  일반 SwiftUI에서와 마찬가지로 Composable Architecture에서도 애니메이션을 수행할 수 있습니다.

  스토어에 액션이 전송될 때 상태 변경을 애니메이션화하려면 명시적인 애니메이션을 전달하거나, withAnimation 블록 안에서 store.send를 호출할 수 있습니다.

  바인딩을 통해 상태 변경을 애니메이션화하려면, Binding에 animation 메소드를 호출할 수 있습니다.

  효과를 통해 비동기 상태 변경을 애니메이션화하려면, 애니메이션을 동반한 액션을 전송할 수 있는 Effect.run 스타일의 효과를 사용하세요.

  화면의 어느 곳이든 탭하거나 드래그하여 점을 이동시키고, 화면 하단의 토글을 전환하여 데모를 시도해 보세요.
  """

@Reducer
struct Animations {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var circleCenter: CGPoint?
    var circleColor = Color.black
    var isCircleScaled = false
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case circleScaleToggleChanged(Bool)
    case rainbowButtonTapped
    case resetButtonTapped
    case setColor(Color)
    case tapped(CGPoint)

    @CasePathable
    enum Alert: Sendable {
      case resetConfirmationButtonTapped
    }
  }

  @Dependency(\.continuousClock) var clock

  private enum CancelID { case rainbow }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.resetConfirmationButtonTapped)):
        state = State()
        return .cancel(id: CancelID.rainbow)

      case .alert:
        return .none

      case let .circleScaleToggleChanged(isScaled):
        state.isCircleScaled = isScaled
        return .none

      case .rainbowButtonTapped:
        return .run { send in
          for color in [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .black] {
            await send(.setColor(color), animation: .linear)
            try await clock.sleep(for: .seconds(1))
          }
        }
        .cancellable(id: CancelID.rainbow)

      case .resetButtonTapped:
        state.alert = AlertState {
          TextState("Reset state?")
        } actions: {
          ButtonState(
            role: .destructive,
            action: .send(.resetConfirmationButtonTapped, animation: .default)
          ) {
            TextState("Reset")
          }
          ButtonState(role: .cancel) {
            TextState("Cancel")
          }
        }
        return .none

      case let .setColor(color):
        state.circleColor = color
        return .none

      case let .tapped(point):
        state.circleCenter = point
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

struct AnimationsView: View {
  @Bindable var store: StoreOf<Animations>

  var body: some View {
    VStack(alignment: .leading) {
      Text(template: readMe, .body)
        .padding()
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { gesture in
            store.send(
              .tapped(gesture.location),
              animation: .interactiveSpring(response: 0.25, dampingFraction: 0.1)
            )
          }
        )
        .overlay {
          GeometryReader { proxy in
            Circle()
              .fill(store.circleColor)
              .colorInvert()
              .blendMode(.difference)
              .frame(width: 50, height: 50)
              .scaleEffect(store.isCircleScaled ? 2 : 1)
              .position(
                x: store.circleCenter?.x ?? proxy.size.width / 2,
                y: store.circleCenter?.y ?? proxy.size.height / 2
              )
              .offset(y: store.circleCenter == nil ? 0 : -44)
          }
          .allowsHitTesting(false)
        }
      Toggle(
        "Big mode",
        isOn:
          $store.isCircleScaled.sending(\.circleScaleToggleChanged)
          .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
      )
      .padding()
      Button("Rainbow") { store.send(.rainbowButtonTapped, animation: .linear) }
        .padding([.horizontal, .bottom])
      Button("Reset") { store.send(.resetButtonTapped) }
        .padding([.horizontal, .bottom])
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    AnimationsView(
      store: Store(initialState: Animations.State()) {
        Animations()
      }
    )
  }
}

#Preview("Dark mode") {
  NavigationStack {
    AnimationsView(
      store: Store(initialState: Animations.State()) {
        Animations()
      }
    )
  }
  .environment(\.colorScheme, .dark)
}
