import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 애플리케이션은 장기 지속 효과를 처리하는 방법을 보여줍니다. 예를 들어, Notification Center에서 알림을 받는 것과 같은 경우와 뷰의 수명에 효과의 수명을 묶는 방법입니다.

  이 애플리케이션을 시뮬레이터에서 실행하고, 메뉴에서 Device › Screenshot으로 가서 몇 번 스크린샷을 찍어보세요. 그리고 UI가 그 횟수를 어떻게 세는지 관찰하세요.

  그 다음, 다른 화면으로 넘어가서 거기에서 스크린샷을 찍어보세요. 이 화면에서는 그 스크린샷들을 세지 않는다는 것을 관찰할 수 있습니다. 알림 효과는 화면을 떠날 때 자동으로 취소되고, 화면에 다시 들어올 때 재시작됩니다.
  """

@Reducer
struct LongLivingEffects {
  @ObservableState
  struct State: Equatable {
    var screenshotCount = 0
  }

  enum Action {
    case task
    case userDidTakeScreenshotNotification
  }

  @Dependency(\.screenshots) var screenshots

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        // When the view appears, start the effect that emits when screenshots are taken.
        return .run { send in
          for await _ in await self.screenshots() {
            await send(.userDidTakeScreenshotNotification)
          }
        }

      case .userDidTakeScreenshotNotification:
        state.screenshotCount += 1
        return .none
      }
    }
  }
}

extension DependencyValues {
  var screenshots: @Sendable () async -> AsyncStream<Void> {
    get { self[ScreenshotsKey.self] }
    set { self[ScreenshotsKey.self] = newValue }
  }
}

private enum ScreenshotsKey: DependencyKey {
  static let liveValue: @Sendable () async -> AsyncStream<Void> = {
    await AsyncStream(
      NotificationCenter.default
        .notifications(named: UIApplication.userDidTakeScreenshotNotification)
        .map { _ in }
    )
  }
}

struct LongLivingEffectsView: View {
  let store: StoreOf<LongLivingEffects>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Text("이 화면의 스크린샷이 \(store.screenshotCount)번 촬영되었습니다.")
        .font(.headline)

      Section {
        NavigationLink {
          detailView
        } label: {
          Text("Navigate to 다른 화면")
        }
      }
    }
    .navigationTitle("Long-living effects")
    .task { await store.send(.task).finish() }
  }

  var detailView: some View {
    Text(
      """
      이 화면의 스크린샷을 몇 번 찍은 다음 이전 화면으로 돌아가 해당 스크린샷이 카운트되지 않았는지 확인하십시오.
      """
    )
    .padding(.horizontal, 64)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    LongLivingEffectsView(
      store: Store(initialState: LongLivingEffects.State()) {
        LongLivingEffects()
      }
    )
  }
}
