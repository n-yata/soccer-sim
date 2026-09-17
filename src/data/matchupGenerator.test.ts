import { describe, it, expect } from "vitest";
import { buildAllMatchups, generateMatchup } from "./matchupGenerator";
import { matchupRules } from "./matchupRules";
import { formations } from "./formations";
import type { Formation, Matchup } from "@/types/formation";

function findFormation(id: string): Formation {
  const formation = formations.find((f) => f.id === id);
  if (!formation) throw new Error(`テストの前提が崩れている: フォーメーション ${id} が無い`);
  return formation;
}

/**
 * タグを1つも持たないフォーメーション（GKだけ・人数構成がどのタグにも当たらない）。
 * フォールバックの検証に使う。本番コードにテスト用の分岐を入れないため、
 * 「ルールが当たらない入力」をデータ側で作って渡す。
 */
const tagless: Formation = {
  id: "tagless",
  name: "タグ無し",
  description: "テスト用。どの導出条件にも当たらない配置",
  stats: { attack: 10, defense: 10, balance: 10, spaceControl: 90, pressIntensity: 10 },
  positions: [
    { id: "tagless-gk", type: "GK", label: "GK", x: 50, y: 5 },
    { id: "tagless-df1", type: "DF", label: "CB", x: 40, y: 20 },
    { id: "tagless-df2", type: "DF", label: "CB", x: 60, y: 20 },
    { id: "tagless-mf1", type: "MF", label: "CM", x: 50, y: 50 },
  ],
};

describe("generateMatchup", () => {
  it("全ての2件組み合わせで、advantagesForA/Bがそれぞれ1件以上生成される", () => {
    const generated = buildAllMatchups(formations);
    expect(generated.length).toBe((formations.length * (formations.length - 1)) / 2);
    for (const matchup of generated) {
      expect(matchup.advantagesForA.length, `${matchup.id} のA側が空`).toBeGreaterThan(0);
      expect(matchup.advantagesForB.length, `${matchup.id} のB側が空`).toBeGreaterThan(0);
      expect(matchup.overallReason.trim(), `${matchup.id} の理由が空`).not.toBe("");
    }
  });

  // 校正アンカー（design.md）。ルール表が左右非対称になると、特定のフォーメーションが
  // 不当に有利判定される。その歪みは「判定が変わった」という形でしか表面化しないため、
  // 手書き時代の判定をここで固定して検知する。
  // 一致しなくなったときは、しきい値ではなくルール表（片側に厚い／逆側から見た噛み合わせの
  // 書き漏れ）を直すこと。しきい値で合わせるとフォーメーション追加時に全組が崩れる。
  const CALIBRATION_ANCHORS: [string, string, Matchup["overallEdge"]][] = [
    ["4-4-2", "4-3-3", "even"],
    ["4-4-2", "4-2-3-1", "B"],
    ["4-4-2", "3-5-2", "B"],
    ["4-3-3", "4-2-3-1", "even"],
    ["4-3-3", "3-5-2", "B"],
    ["4-2-3-1", "3-5-2", "even"],
  ];

  it.each(CALIBRATION_ANCHORS)(
    "%s vs %s の総合判定が手書き時代と同じ %s になる",
    (aId, bId, expected) => {
      const matchup = generateMatchup(findFormation(aId), findFormation(bId));
      expect(matchup.overallEdge).toBe(expected);
    },
  );

  it("overallReasonに「Aは」「Bの」等のA/B相対表現が含まれない", () => {
    // getMatchup は入れ替え時に overallEdge のみ反転し overallReason はそのまま返すため、
    // 相対表現が入ると逆側のフォーメーションを指す文言として表示される
    const relativeExpressionPattern = /(^|[はがのを])[AB]([はがのを]|$)/;
    const offenders = buildAllMatchups(formations)
      .filter((matchup) => relativeExpressionPattern.test(matchup.overallReason))
      .map((matchup) => matchup.id);
    expect(offenders).toEqual([]);
  });

  it("overallReasonに、判定された側のフォーメーション名が含まれる", () => {
    for (const matchup of buildAllMatchups(formations)) {
      if (matchup.overallEdge === "even") continue;
      const winnerId = matchup.overallEdge === "A" ? matchup.formationAId : matchup.formationBId;
      expect(matchup.overallReason, `${matchup.id} に勝者名が無い`).toContain(
        findFormation(winnerId).name,
      );
    }
  });

  it("同じ入力に対して常に同じ結果を返す（Math.randomを使っていないことの担保）", () => {
    const first = buildAllMatchups(formations);
    const second = buildAllMatchups(formations);
    expect(second).toEqual(first);
  });

  it("組み合わせが違えば、同じルールでも言い回しが固定されるわけではない", () => {
    // ペアIDをシードにした決定的な選択を採っているため、ルールが同じでも組み合わせが
    // 違えば別の言い回しが選ばれうる。ここでは「ペアごとに独立して決まる」ことを、
    // 実際に異なる文言が現れる例で確認する（全組で同一文言が並ぶ単調さの防止）
    const wingVsFourBack = [
      generateMatchup(findFormation("4-4-2"), findFormation("4-3-3")).advantagesForB[0],
      generateMatchup(findFormation("4-3-3"), findFormation("4-2-3-1")).advantagesForA[0],
    ];
    expect(new Set(wingVsFourBack).size).toBe(2);
  });

  it("idと formationAId/formationBId が引数の順序どおりになる", () => {
    const matchup = generateMatchup(findFormation("4-4-2"), findFormation("4-2-3-1"));
    expect(matchup.id).toBe("4-4-2_vs_4-2-3-1");
    expect(matchup.formationAId).toBe("4-4-2");
    expect(matchup.formationBId).toBe("4-2-3-1");
  });

  describe("ルールが1件も当たらない場合", () => {
    it("両側ともフォールバックの優位ポイントを返し、空配列にならない", () => {
      const matchup = generateMatchup(tagless, { ...tagless, id: "tagless2", name: "タグ無し2" });
      expect(matchup.advantagesForA).toHaveLength(1);
      expect(matchup.advantagesForB).toHaveLength(1);
      // stats の最大軸（spaceControl）由来の汎用文が返る
      expect(matchup.advantagesForA[0]).toContain("ピッチの幅");
      expect(matchup.overallEdge).toBe("even");
      expect(matchup.overallReason).toContain("優劣がつきにくい");
    });

    it("片側だけルールが当たらない場合も、当たらない側にフォールバックが入る", () => {
      const matchup = generateMatchup(findFormation("4-3-3"), tagless);
      expect(matchup.advantagesForB).toHaveLength(1);
      expect(matchup.advantagesForB[0]).toContain("ピッチの幅");
      expect(matchup.advantagesForA.length).toBeGreaterThan(0);
    });

    it("statsの最大軸に応じてフォールバックの文言が変わる", () => {
      const defensive: Formation = {
        ...tagless,
        stats: { attack: 10, defense: 95, balance: 10, spaceControl: 10, pressIntensity: 10 },
      };
      const matchup = generateMatchup(defensive, { ...tagless, id: "tagless2" });
      expect(matchup.advantagesForA[0]).toContain("ゴール前を固めやすい");
    });
  });

  it("フォーメーションが1件以下なら組み合わせが作れず空配列を返す", () => {
    expect(buildAllMatchups([])).toEqual([]);
    expect(buildAllMatchups([findFormation("4-4-2")])).toEqual([]);
  });

  // 同じ戦術を別の切り口で書いたルールが同時に当たると、ほぼ同じ文が並んだうえ
  // 優劣スコアが二重に積まれる（文字列は異なるため完全一致の重複検知はすり抜ける）。
  // matchupRules の theme がこれを構造的に防いでいるが、間引きが外れても総合判定が
  // 閾値をまたがなければ校正アンカーは緑のままになる。実際に出る件数を固定して、
  // 「増えたこと」そのものを検知する。
  //
  // 期待値は設計からの導出ではなく、間引き実装後の実出力を確認して固定したもの。
  // ルールを追加・変更するとここが赤くなる。そのときは件数を書き換える前に
  // 「増えた分は本当に別の戦術か（重複発火ではないか）」を必ず確認すること。
  it("実データの全組み合わせで、優位ポイントの件数が想定どおり（重複発火の検知）", () => {
    // A-2でフォーメーションが4種→8種、組み合わせが6組→28組に増えたことに伴う更新。
    // 既存6組の値はA-1時点から不変（既存4種のタグ・ルールを変えていないため）。
    //
    // フェーズ8-2（コミット前レビュー Medium 4 対応）でR30〜R39を追加。
    // フェーズ9（コミット前レビュー Medium 4 の続き。4-1-2-1-2/4-1-4-1 の一方的な
    // 負け越しの是正）でR32b/R33b/R34bを追加し、R27の文言（「中央に寄る」という
    // 中盤ダイヤが保証しない性質の断定）を修正した。
    //
    // フェーズ9で発見した制約の競合: 負けを減らすルールを足すと、相手側の「勝ち」が
    // 「分け」に変わるため、even率が必然的に上がる（設計上のトレードオフ。
    // retrospective.md参照）。4-1-2-1-2は0勝5敗2分→0勝2敗5分まで改善したが、
    // 勝ちを作るには至っていない。even率は57.1%→67.9%へ悪化した。
    const expected: Record<string, { a: number; b: number }> = {
      "4-4-2_vs_4-3-3": { a: 2, b: 2 },
      "4-4-2_vs_4-2-3-1": { a: 2, b: 4 },
      "4-4-2_vs_3-5-2": { a: 1, b: 3 },
      "4-4-2_vs_5-3-2": { a: 2, b: 1 },
      "4-4-2_vs_4-1-4-1": { a: 1, b: 2 },
      "4-4-2_vs_3-4-3": { a: 2, b: 4 },
      "4-4-2_vs_4-1-2-1-2": { a: 2, b: 2 },
      "4-3-3_vs_4-2-3-1": { a: 2, b: 3 },
      "4-3-3_vs_3-5-2": { a: 2, b: 4 },
      "4-3-3_vs_5-3-2": { a: 1, b: 2 },
      "4-3-3_vs_4-1-4-1": { a: 2, b: 3 },
      "4-3-3_vs_3-4-3": { a: 3, b: 3 },
      "4-3-3_vs_4-1-2-1-2": { a: 3, b: 3 },
      "4-2-3-1_vs_3-5-2": { a: 2, b: 2 },
      "4-2-3-1_vs_5-3-2": { a: 2, b: 3 },
      "4-2-3-1_vs_4-1-4-1": { a: 2, b: 2 },
      "4-2-3-1_vs_3-4-3": { a: 4, b: 3 },
      "4-2-3-1_vs_4-1-2-1-2": { a: 4, b: 2 },
      "3-5-2_vs_5-3-2": { a: 4, b: 1 },
      "3-5-2_vs_4-1-4-1": { a: 2, b: 2 },
      "3-5-2_vs_3-4-3": { a: 2, b: 3 },
      "3-5-2_vs_4-1-2-1-2": { a: 4, b: 2 },
      "5-3-2_vs_4-1-4-1": { a: 3, b: 1 },
      "5-3-2_vs_3-4-3": { a: 1, b: 4 },
      "5-3-2_vs_4-1-2-1-2": { a: 3, b: 2 },
      "4-1-4-1_vs_3-4-3": { a: 3, b: 2 },
      "4-1-4-1_vs_4-1-2-1-2": { a: 3, b: 3 },
      "3-4-3_vs_4-1-2-1-2": { a: 4, b: 3 },
    };

    const actual = Object.fromEntries(
      buildAllMatchups(formations).map((matchup) => [
        matchup.id,
        { a: matchup.advantagesForA.length, b: matchup.advantagesForB.length },
      ]),
    );
    expect(actual).toEqual(expected);
  });

  // テーマによる間引きは「ルールを黙って落とす」仕組みなので、あるルールが全組み合わせで
  // 一度も採用されない＝データ上は存在するのに永遠に出力されない、という状態を作りうる。
  // 実際に旧 R17 がこれで死に、「ライン間」の語が生成文言から丸ごと消えた
  // （用語集テストは radarAxes の説明文で偶然拾えていたため緑のままだった）。
  //
  // 到達不能そのものは必ずしも誤りではない（フォーメーションが増えれば到達しうる）。
  // そのため「許容する到達不能ルール」を明示し、それ以外が死んだら赤くする。
  // ここへ追加するときは、そのルールが運ぶ用語が他のルールでも登場するかを必ず確認すること。
  it("採用されないルールが、許容リスト以外に存在しない", () => {
    // R11（中盤フラット4枚 × ウイングバック有）は、A-1時点（既存4種のみ）では
    // 4-4-2 vs 3-5-2 でしか成立条件が揃わず、同テーマで先行する R13（4バック × ウイングバック有）
    // に必ず吸収されていた。A-2で3-4-3（3バックかつ中盤フラット4枚）を追加したことで
    // R13が当たらずR11だけが当たる組み合わせが生まれ、到達可能になったため許容リストから外した
    // R21c（5バック × 3トップ）は、現行データで3トップを持つ形（4-3-3・3-4-3）が
    // どちらもウイング有を併せ持つため、同一テーマでより具体的なR22（5バック×ウイング有）に
    // 必ず吸収され、到達不能になっている。これはR21分割前から同じ挙動（分割前のR21も
    // この2組ではR22に吸収されていた）で、スコア・判定への影響は無い。
    // 3トップかつウイング有を持たない形が将来追加されれば到達可能になる
    const allowedUnreachable: string[] = ["R21c"];

    // 採用されたルールは、生成された文言から逆引きする。本番コードへテスト用の
    // 内部公開を足さないため（優位ポイントの文言はルールの advantages から選ばれる）
    const ruleIdByAdvantage = new Map<string, string>();
    for (const rule of matchupRules) {
      for (const text of rule.advantages) ruleIdByAdvantage.set(text, rule.id);
    }

    const used = new Set<string>();
    for (const matchup of buildAllMatchups(formations)) {
      for (const text of [...matchup.advantagesForA, ...matchup.advantagesForB]) {
        const ruleId = ruleIdByAdvantage.get(text);
        // 見つからない＝フォールバック文。ルールの採用状況とは無関係なので無視する
        if (ruleId !== undefined) used.add(ruleId);
      }
    }

    const unreachable = matchupRules
      .map((rule) => rule.id)
      .filter((id) => !used.has(id) && !allowedUnreachable.includes(id));
    expect(unreachable).toEqual([]);
  });

  // A-2の中心的な品質ゲート。着手前の実測で新規が絡む22組のうち9組が片側0件になり、
  // 解説がstats由来の汎用フォールバック文に落ちていた（design.md参照）。
  // R21〜R29を追加した結果として「フォールバックに頼る組が0」を固定する。
  // ルール表の advantages からの逆引きで判定する（フォールバック文はどのルールの
  // advantagesにも登場しないため、逆引きできない=フォールバックという判定になる）
  it("28組すべてで、両サイドの優位ポイントがすべてルール由来である（フォールバックが混ざらない）", () => {
    const knownAdvantageTexts = new Set(matchupRules.flatMap((rule) => rule.advantages));

    const offenders: string[] = [];
    for (const matchup of buildAllMatchups(formations)) {
      const isFallback = (text: string) => !knownAdvantageTexts.has(text);
      if (matchup.advantagesForA.some(isFallback)) offenders.push(`${matchup.id} (A側)`);
      if (matchup.advantagesForB.some(isFallback)) offenders.push(`${matchup.id} (B側)`);
    }
    expect(offenders).toEqual([]);
  });

  // 実際に起きた事故の再発防止。フォーメーションを8種へ増やしたとき、
  // 4-2-3-1 vs 4-1-4-1（どちらも 1トップ＋4バック）で同じルールが左右両方に発火し、
  // 文言選択のシードがペアIDとルールIDだけだったため **一字一句同じ文が左右に並んだ**。
  // 既存の重複検知は片側の配列内しか見ないため、テストは緑のまま画面だけが破綻していた。
  it("左右の優位ポイントに、同一の文言が現れない", () => {
    const offenders: string[] = [];
    for (const matchup of buildAllMatchups(formations)) {
      const shared = matchup.advantagesForA.filter((text) => matchup.advantagesForB.includes(text));
      if (shared.length > 0) {
        offenders.push(`${matchup.id}: ${shared.join(" / ")}`);
      }
    }
    expect(offenders).toEqual([]);
  });

  // 上と同じ事故の、総合判定側の症状。根拠が左右で一致すると
  // 「{名前}の〜点と、{名前}の〜点が拮抗しており」が同じ内容の繰り返しになる
  it("総合判定の理由が、同じ内容を2回繰り返さない", () => {
    const repeated = /の(.+?)点と、.+?の\1点が/;
    const offenders = buildAllMatchups(formations)
      .filter((matchup) => repeated.test(matchup.overallReason))
      .map((matchup) => `${matchup.id}: ${matchup.overallReason}`);
    expect(offenders).toEqual([]);
  });

  it("同一サイドの優位ポイントに、書き出しが同じ文言が並ばない", () => {
    // 完全一致の重複は matchups.test.ts が見ている。ここで狙うのはその手前、
    // 「言い回しは違うが同じことを言っている」状態。厳密な意味判定はできないので、
    // 書き出しが揃うこと（同じ主語・同じ構文で始まること）を近似として使う
    const offenders: string[] = [];
    for (const matchup of buildAllMatchups(formations)) {
      for (const [label, points] of [
        ["advantagesForA", matchup.advantagesForA],
        ["advantagesForB", matchup.advantagesForB],
      ] as const) {
        const heads = points.map((text) => text.slice(0, 10));
        if (new Set(heads).size !== heads.length) {
          offenders.push(`${matchup.id} (${label})`);
        }
      }
    }
    expect(offenders).toEqual([]);
  });
});
