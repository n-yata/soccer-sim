import { describe, it, expect } from "vitest";
import { matchupRules } from "./matchupRules";
import { soccerTerms } from "./soccerTerms";

const allRuleText = matchupRules.flatMap((rule) => [...rule.advantages, rule.reason]).join("\n");

describe("matchupRules", () => {
  // ある用語を1つのルールだけが運んでいる場合、そのルールの言い回しは
  // **どれが選ばれても用語が残る**必要がある（matchupGenerator は advantages から
  // 1つを決定的に選ぶため）。soccerTerms.test.ts は「生成後のどこかに1回出る」ことしか
  // 見ないので、発火する組が少ないルールでは、用語を含まない言い回しを足した瞬間に
  // 選ばれ方次第で語が消え、しかもテストは緑のままになる。
  //
  // 下の表は「この用語はこのルールが唯一の運び手」という対応。運び手を移したり
  // 言い回しを足したときに、ここが赤くなって気づけるようにする。
  it.each([
    { ruleId: "R25", term: "コンパクトな守備ブロック" },
    { ruleId: "R05", term: "5レーン" },
    { ruleId: "R04", term: "マンツーマン" },
    { ruleId: "R03", term: "ピン留め" },
  ])("$ruleId の全ての言い回しに「$term」が含まれる", ({ ruleId, term }) => {
    const rule = matchupRules.find((candidate) => candidate.id === ruleId);
    expect(rule, `${ruleId} が見つからない（IDを変えたならこの表も更新すること）`).toBeDefined();

    const missing = rule!.advantages.filter((text) => !text.includes(term));
    expect(missing, `${ruleId} の言い回しに「${term}」を含まないものがある`).toEqual([]);
  });

  // 用語集は「実際の文言に登場する語のみを収録する」という不変条件を持ち、
  // soccerTerms.test.ts が生成後のマッチアップ文言に対してそれを検証している。
  // ここではその手前のルール表の段階で落とすことで、「どのルールに用語を足せばよいか」を
  // 特定しやすくする（生成後に落ちると、どの組み合わせで語彙が欠けたのか追いにくい）。
  it("ルール表の文言に、用語集の全用語が登場する", () => {
    const missing = soccerTerms
      .map((term) => term.term)
      .filter((term) => !allRuleText.includes(term));
    expect(missing).toEqual([]);
  });

  it("ルールIDが一意である", () => {
    const ids = matchupRules.map((rule) => rule.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("全ルールがadvantagesを1件以上持ち、空文字を含まない", () => {
    expect(matchupRules.length).toBeGreaterThan(0);
    for (const rule of matchupRules) {
      expect(rule.advantages.length, `${rule.id} のadvantagesが空`).toBeGreaterThan(0);
      for (const advantage of rule.advantages) {
        expect(advantage.trim(), `${rule.id} に空文字のadvantageがある`).not.toBe("");
      }
    }
  });

  it("全ルールが空でないreasonと、タグ条件を1つ以上持つ", () => {
    for (const rule of matchupRules) {
      expect(rule.reason.trim(), `${rule.id} のreasonが空`).not.toBe("");
      // selfTags/opponentTagsの両方が空のルールは全組み合わせに無条件で当たり、
      // 総合優劣に寄与しないノイズになる（定義ミスの検知）
      expect(
        rule.selfTags.length + rule.opponentTags.length,
        `${rule.id} が無条件ルールになっている`,
      ).toBeGreaterThan(0);
    }
  });

  // フェーズ8-1（コミット前レビュー Medium 3 対応）。opponentTagsが空＝相手条件なしの
  // ルールは、selfTagsを持つ形に対して無条件で加点する絶対値評価になり、
  // matchupGenerator.tsが明言する「statsを優劣に使わない」方針と筋が合わない
  // （旧R21がこれだった。R21a/b/cへ分割して解消した）。
  // 既存ガード「selfTags.length + opponentTags.length > 0」は片側だけ空のケースを
  // 検知できないため、ここで直接固定する
  it("opponentTagsが空（相手条件なし）のルールが存在しない", () => {
    const unconditional = matchupRules
      .filter((rule) => rule.opponentTags.length === 0)
      .map((rule) => rule.id);
    expect(unconditional).toEqual([]);
  });

  it("同一ルールのadvantages内に重複する文言が無い", () => {
    const duplicated = matchupRules
      .filter((rule) => new Set(rule.advantages).size !== rule.advantages.length)
      .map((rule) => rule.id);
    expect(duplicated).toEqual([]);
  });

  // 別ルールが同じ文言を持つと、両方が適用された組み合わせで箇条書きが重複し、
  // matchups.test.ts の重複検知が落ちる（原因がルール表側にあることを先に示す）
  it("ルールをまたいでも優位ポイントの文言が重複しない", () => {
    const all = matchupRules.flatMap((rule) => rule.advantages);
    const seen = new Set<string>();
    const duplicated = all.filter((text) => (seen.has(text) ? true : (seen.add(text), false)));
    expect(duplicated).toEqual([]);
  });

  it("優位ポイントの文言に「Aの」「Bの」等のA/B相対表現が含まれない", () => {
    // 優位ポイントは getMatchup の入れ替えで表示側が反転するため、A/B を指す表現は
    // 逆側のフォーメーションの説明として表示されてしまう
    const relativeExpressionPattern = /(^|[はがのを])[AB]([はがのを]|$)/;
    const offenders = matchupRules
      .filter(
        (rule) =>
          rule.advantages.some((text) => relativeExpressionPattern.test(text)) ||
          relativeExpressionPattern.test(rule.reason),
      )
      .map((rule) => rule.id);
    expect(offenders).toEqual([]);
  });

  it("全ルールのscoreが1以上の整数である", () => {
    for (const rule of matchupRules) {
      expect(Number.isInteger(rule.score), `${rule.id} のscoreが整数でない`).toBe(true);
      expect(rule.score, `${rule.id} のscoreが1未満`).toBeGreaterThanOrEqual(1);
    }
  });

  // 実際に起きた事故の再発防止。かつて R18(self:[ウイングバック有]) と
  // R19(self:[3バック,ウイングバック有]) が併存し、R19 が当たる側では R18 も必ず当たっていた。
  // ほぼ同じ文が2行並んだうえ優劣スコアが二重に積まれていたが、文字列は異なるため
  // 重複検知をすり抜け、テストは緑のまま総合判定だけが片側へ静かに歪んでいた。
  //
  // 同一テーマ内の包含は matchupGenerator が1件へ間引くので害にならない。危険なのは
  // **テーマをまたいだ包含**で、これは間引きの対象外＝二重計上がそのまま残る。
  it("条件が別ルールの上位集合になっているルールが、テーマをまたいで存在しない", () => {
    const isSubsetOf = (inner: readonly string[], outer: readonly string[]) =>
      inner.every((tag) => outer.includes(tag));

    const offenders: string[] = [];
    for (const outer of matchupRules) {
      for (const inner of matchupRules) {
        if (outer.id === inner.id) continue;
        if (outer.theme === inner.theme) continue;
        // inner の条件が outer の条件に含まれる = outer が当たれば inner も必ず当たる
        if (
          isSubsetOf(inner.selfTags, outer.selfTags) &&
          isSubsetOf(inner.opponentTags, outer.opponentTags)
        ) {
          offenders.push(
            `${outer.id}(${outer.theme}) が ${inner.id}(${inner.theme}) を包含している`,
          );
        }
      }
    }
    expect(offenders).toEqual([]);
  });
});
