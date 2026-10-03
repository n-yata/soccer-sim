import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { reactive } from "vue";
import ComparisonPage from "./ComparisonPage.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import RadarChart from "@/components/RadarChart.vue";
import TacticalReplay from "@/components/TacticalReplay.vue";
import { getFormationById } from "@/data/formations";
import { buildPairKey, loadProgress } from "@/data/learningProgress";

const pushMock = vi.fn();
const replaceMock = vi.fn();
// vue-router の useRoute() は reactive なオブジェクトを返す。plain object のままだと
// route.params を書き換えても ComparisonPage 内の computed / watch が再評価されず、
// A/B切替時の記録を検証できない
const routeState = reactive({
  params: { formationAId: "4-2-3-1", formationBId: "4-4-2" } as {
    formationAId: string;
    formationBId: string;
  },
});

vi.mock("vue-router", () => ({
  useRoute: () => routeState,
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
}));

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to"><slot /></a>',
};

describe("ComparisonPage", () => {
  it("比較画面に陣形別の場面教材を置かない", () => {
    const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    try {
      expect(wrapper.findComponent(TacticalReplay).exists()).toBe(false);
      expect(wrapper.find('[data-testid="replay-open"]').exists()).toBe(false);
      expect(wrapper.find(".comparison-page__advantages").exists()).toBe(true);
    } finally {
      wrapper.unmount();
    }
  });

  beforeEach(() => {
    pushMock.mockClear();
    replaceMock.mockClear();
    routeState.params = { formationAId: "4-2-3-1", formationBId: "4-4-2" };
    window.localStorage.clear();
  });

  it("固定配置の比較だけを表示し、保存済み自由配置を参照しない", () => {
    window.localStorage.setItem(
      "formation-lab.free-layout-overrides.v1",
      JSON.stringify({ "4-2-3-1": { "4-2-3-1-gk": { x: 99, y: 99 } } }),
    );
    const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    try {
      expect(wrapper.text()).not.toMatch(
        /自由配置|シミュレート|試合で確かめる|ハーフタイム|配置と選手の設定/,
      );
      expect(wrapper.find(".comparison-page__options").exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulation").exists()).toBe(false);
      expect(wrapper.getComponent(MatchupPitchDiagram).props("formationA")).toEqual(
        getFormationById("4-2-3-1"),
      );
      expect(wrapper.getComponent(RadarChart).props("series")[0].values).toEqual(
        getFormationById("4-2-3-1")!.stats,
      );
      expect(wrapper.find(".comparison-page__advantages").exists()).toBe(true);
      expect(
        wrapper
          .getComponent(MatchupPitchDiagram)
          .props("formationA")
          .positions.find((p: { id: string }) => p.id === "4-2-3-1-gk"),
      ).toMatchObject({ x: 50, y: 5 });
      expect(window.localStorage.getItem("formation-lab.free-layout-overrides.v1")).toContain(
        '"4-2-3-1-gk":{"x":99,"y":99}',
      );
    } finally {
      wrapper.unmount();
    }
  });

  // FR-13: 表示できた組み合わせを学習進捗として記録する
  describe("学習進捗の記録", () => {
    // routeStateはreactiveな共有オブジェクトのため、mountしたコンポーネントを
    // unmountしないままにすると、次のテストのbeforeEachでrouteState.paramsを
    // 書き換えた瞬間に「前のテストで残っていたウォッチャー」まで再発火し、
    // localStorageを汚染して他のテストを壊す。ここで確実に片付ける
    let mountedWrappers: ReturnType<typeof mount>[] = [];
    function mountAndTrack() {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      mountedWrappers.push(wrapper);
      return wrapper;
    }

    beforeEach(() => {
      mountedWrappers = [];
    });

    afterEach(() => {
      mountedWrappers.forEach((wrapper) => wrapper.unmount());
    });

    it("マウント時に、表示している組み合わせを確認済みとして記録する", () => {
      mountAndTrack();

      expect(loadProgress().viewedPairs).toContain(buildPairKey("4-2-3-1", "4-4-2"));
    });

    it("A/B入れ替え・切替（同一コンポーネント内のパラメータ変更）でも記録される", async () => {
      const wrapper = mountAndTrack();

      // router.replace 後、実際のアプリでは route.params が更新される。
      // ここでは同一コンポーネント内でのパラメータ変更を、テストからルート状態を
      // 直接書き換えることで再現する
      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(loadProgress().viewedPairs).toContain(buildPairKey("3-5-2", "4-4-2"));
    });

    it("順序を入れ替えて表示しても、進捗としては同一の組み合わせとして扱われる（二重計上しない）", async () => {
      mountAndTrack();
      expect(loadProgress().viewedPairs).toHaveLength(1);

      routeState.params = { formationAId: "4-4-2", formationBId: "4-2-3-1" };
      const wrapper2 = mountAndTrack();
      await wrapper2.vm.$nextTick();

      expect(loadProgress().viewedPairs).toHaveLength(1);
    });

    it("存在しない組み合わせ（マッチアップ未検出）では記録しない", () => {
      routeState.params = { formationAId: "4-4-2", formationBId: "4-4-2" };
      mountAndTrack();

      expect(loadProgress().viewedPairs).toHaveLength(0);
    });
  });

  it("正しいIDでマウントすると、タイトル・重ね合わせピッチ図・優位ポイントの箇条書きが表示される", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("4-2-3-1 vs 4-4-2");

    const matchupPitch = wrapper.findComponent(MatchupPitchDiagram);
    expect(matchupPitch.exists()).toBe(true);
    expect(matchupPitch.props("formationA")?.id).toBe("4-2-3-1");
    expect(matchupPitch.props("formationB")?.id).toBe("4-4-2");

    const columns = wrapper.findAll(".comparison-page__advantage-column");
    expect(columns).toHaveLength(2);
    columns.forEach((column) => {
      expect(column.findAll("li").length).toBeGreaterThan(0);
    });

    // このケースはルートパラメータが data/matchups.ts のレコード格納順序（"4-4-2"→"4-2-3-1"）
    // と逆（"4-2-3-1"→"4-4-2"）なので、getMatchup の正規化ロジック（入れ替え）を通る。
    // 青カラム（formationA="4-2-3-1"側）に4-2-3-1の優位ポイントが、赤カラム
    // （formationB="4-4-2"側）に4-4-2の優位ポイントが表示されることを直接検証する
    // （取り違えて逆に表示されてもテストが緑になる恒真テストを避けるため）。
    expect(columns[0].text()).toContain(
      "守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に対応でき",
    );
    expect(columns[1].text()).toContain(
      "2トップが相手の守備的MF2枚の脇や背後のスペースを突きやすい",
    );

    // 総合判定（どちらが有利か）が表示される。この組み合わせは overallEdge が
    // 入れ替えにより "B"→"A" に反転し、formationA（4-2-3-1）がやや優位と表示される
    const verdict = wrapper.find(".comparison-page__verdict");
    expect(verdict.text()).toContain("4-2-3-1がやや優位");
  });

  it("RadarChartにformationA/Bのstatsがそれぞれ正しく渡る", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const radarChart = wrapper.findComponent(RadarChart);
    expect(radarChart.exists()).toBe(true);

    const formationA = getFormationById("4-2-3-1");
    const formationB = getFormationById("4-4-2");
    const series = radarChart.props("series") as {
      label: string;
      colorVar: string;
      values: unknown;
    }[];
    expect(series).toHaveLength(2);
    expect(series[0]).toEqual({
      label: "4-2-3-1",
      colorVar: "--color-team-a",
      values: formationA?.stats,
    });
    expect(series[1]).toEqual({
      label: "4-4-2",
      colorVar: "--color-team-b",
      values: formationB?.stats,
    });
  });

  it("overallEdgeがevenの組み合わせでは、総合判定に「互角」と表示される", () => {
    routeState.params = { formationAId: "4-4-2", formationBId: "4-3-3" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const verdict = wrapper.find(".comparison-page__verdict");
    expect(verdict.text()).toContain("互角");
  });

  it("formationAIdが存在しない場合、エラーメッセージが表示されピッチ図は描画されない", () => {
    routeState.params = { formationAId: "存在しないID", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("formationBIdが存在しない場合も同様にエラーメッセージが表示される", () => {
    routeState.params = { formationAId: "4-2-3-1", formationBId: "存在しないID" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("同一フォーメーション同士のIDでアクセスした場合、エラーメッセージが表示されピッチ図は描画されない", () => {
    // 一覧画面はトグル方式のため通常発生しないが、URL直打ちで到達しうる状態
    // （getFormationByIdは両方成功するがgetMatchupがundefinedになるケース）。
    routeState.params = { formationAId: "4-4-2", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("「← 戻る」をクリックするとrouter.pushが'/'で1回呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    await wrapper.find("button").trigger("click");
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/");
  });

  it("エラー時に表示される一覧画面へのリンクが'/'を指す", () => {
    routeState.params = { formationAId: "存在しないID", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const link = wrapper.find("a");
    expect(link.attributes("href")).toBe("/");
  });

  it("comparison-page__mainがflex-wrap:wrapで、狭い画面でピッチ図とレーダーチャートが横並びから縦積みへ切り替わる", () => {
    const wrapper = mount(ComparisonPage, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    const main = wrapper.find(".comparison-page__main");
    const mainStyle = getComputedStyle(main.element);
    expect(mainStyle.display).toBe("flex");
    // flex-wrap:wrap が外れると、画面が狭くてもピッチ図とレーダーチャートが
    // 常に横並びのままレイアウトが崩れる（縦積みへの切り替えができなくなる）
    expect(mainStyle.flexWrap).toBe("wrap");

    // 各カラムがflex-basisを持つことで、コンテナ幅がbasis合計を下回った際に
    // wrapが発動する。0や未設定に戻すとwrapが機能しなくなるため固定しておく。
    const pitchOverlay = wrapper.find(".comparison-page__pitch-overlay");
    const radar = wrapper.find(".comparison-page__radar");
    expect(getComputedStyle(pitchOverlay.element).flexBasis).toBe("520px");
    expect(getComputedStyle(radar.element).flexBasis).toBe("320px");

    wrapper.unmount();
  });

  it("comparison-page__bodyがページ全体の上限幅を持ち、広い画面幅で中央寄せされる", () => {
    const wrapper = mount(ComparisonPage, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const body = wrapper.find(".comparison-page__body");
    const bodyStyle = getComputedStyle(body.element);
    // jsdomはCSSカスタムプロパティを解決しないため、期待値は「正しいトークン参照を
    // 使っているか」で検証する（design.md「jsdomのCSS変数非解決によるテスト期待値の更新」参照）
    // UI/UXモダナイゼーションPhase3（コンテナ幅の全画面統一）により、
    // 画面ごとに異なるトークン(--width-full)ではなく他画面と同じ--width-wideへ変更
    expect(bodyStyle.maxWidth).toBe("var(--width-wide)");
    expect(bodyStyle.marginLeft).toBe("auto");
    expect(bodyStyle.marginRight).toBe("auto");
    wrapper.unmount();
  });

  it("「⇄ 入れ替え」をクリックすると、A/Bが逆順のURLでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    await wrapper.find(".comparison-controls__swap-button").trigger("click");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/4-4-2/4-2-3-1");
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("青チーム側のセレクトを変更すると、新しい組み合わせでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const select = wrapper.find("#comparison-select-a");
    await select.setValue("3-5-2");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/3-5-2/4-4-2");
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("赤チーム側のセレクトを変更すると、新しい組み合わせでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const select = wrapper.find("#comparison-select-b");
    await select.setValue("3-5-2");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/4-2-3-1/3-5-2");
    expect(pushMock).not.toHaveBeenCalled();
  });

  // FR-11: 解説文中の用語をその場で引ける
  it("優位ポイント中のサッカー用語が、説明を開けるボタンとして表示される", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    const columns = wrapper.findAll(".comparison-page__advantage-column");
    // 青カラムの「守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に…」に含まれる用語
    const termButton = columns[0]
      .findAll("button.term-annotated-text__term")
      .find((b) => b.text() === "マンツーマン");
    expect(termButton).toBeDefined();

    await termButton!.trigger("click");

    const tooltip = columns[0].find('[role="tooltip"]');
    expect(tooltip.exists()).toBe(true);
    expect(tooltip.text()).toContain("相手の特定の1人にほぼ付きっきりで対応する守り方");
  });

  it("総合判定理由の中の用語にも説明を開けるボタンが付く", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    // overallReason は「4-2-3-1は中盤が実質5枚と4-4-2の4枚を上回り、中盤の主導権を握りやすい」
    const reason = wrapper.find(".comparison-page__verdict-reason");
    const labels = reason.findAll("button.term-annotated-text__term").map((b) => b.text());
    expect(labels).toContain("中盤");
  });

  it("用語を注釈しても、優位ポイントの本文が欠落しない", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    // 用語ボタンへの切り出しで文字が落ちたり重複したりしないことを本文全体で確認する
    const columns = wrapper.findAll(".comparison-page__advantage-column");
    expect(columns[0].text().replace(/\s/g, "")).toContain(
      "守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に対応でき、数的な破綻を防ぎやすい",
    );
  });

  it("各セレクトで、相手側に選択済みのフォーメーションがdisabledになっている", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const optionsA = wrapper.find("#comparison-select-a").findAll("option");
    const disabledInA = optionsA.find((option) => option.attributes("value") === "4-4-2");
    expect(disabledInA?.attributes("disabled")).toBeDefined();

    const optionsB = wrapper.find("#comparison-select-b").findAll("option");
    const disabledInB = optionsB.find((option) => option.attributes("value") === "4-2-3-1");
    expect(disabledInB?.attributes("disabled")).toBeDefined();
  });
});
