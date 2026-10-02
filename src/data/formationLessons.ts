import type { FormationLesson } from "@/types/tacticalReplay";
import { wideOverloadScene } from "./tacticalScenes";
import { fourFourTwoLesson } from "./lessons/fourFourTwo";
import { fourTwoThreeOneLesson } from "./lessons/fourTwoThreeOne";
import { threeFiveTwoLesson } from "./lessons/threeFiveTwo";
import { fiveThreeTwoLesson } from "./lessons/fiveThreeTwo";
import { fourOneFourOneLesson } from "./lessons/fourOneFourOne";
import { threeFourThreeLesson } from "./lessons/threeFourThree";
import { diamondLesson } from "./lessons/diamond";

const fourThreeThreeLesson: FormationLesson = {
  formationId: "4-3-3",
  objective: "ウイングが内側へ相手を引きつけ、後ろのサイドバックが外側を追い越す連係を学ぶ。",
  caution:
    "相手のカバーが外へ来たら2対1は続かない。戻す選択肢と、サイドバックの後ろを支える味方も確認しよう。",
  scene: {
    ...wideOverloadScene,
    context:
      "4-3-3の右ウイングと右サイドバックを使った局面です。青が学習する陣形、赤が相手。関係する4人を切り出し、他の選手は省略しています。",
    areaLabel: "右サイドの局面",
    players: wideOverloadScene.players.map((player) => ({
      ...player,
      formationPositionId:
        player.id === "wing" ? "4-3-3-rw" : player.id === "overlap" ? "4-3-3-rb" : undefined,
    })),
  },
};

export const formationLessons: FormationLesson[] = [
  fourFourTwoLesson,
  fourThreeThreeLesson,
  fourTwoThreeOneLesson,
  threeFiveTwoLesson,
  fiveThreeTwoLesson,
  fourOneFourOneLesson,
  threeFourThreeLesson,
  diamondLesson,
];

export function getFormationLesson(id: string): FormationLesson | undefined {
  return formationLessons.find((lesson) => lesson.formationId === id);
}
