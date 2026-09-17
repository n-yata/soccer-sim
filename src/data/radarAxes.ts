import type { RadarAxisId } from "@/types/formation";

export interface RadarAxisMeta {
  id: RadarAxisId;
  label: string;
  description: string;
}

// レーダーチャートの表示順もこの配列順に従う
export const radarAxes: readonly RadarAxisMeta[] = [
  { id: "attack", label: "攻撃力", description: "前線の厚みと攻撃的ポジションの前掛かり度" },
  { id: "defense", label: "守備力", description: "最終ラインの人数と低さ、守備的MFの厚み" },
  { id: "balance", label: "バランス", description: "DF/MF/FWの人数配分の均等さ" },
  { id: "spaceControl", label: "スペース支配力", description: "ピッチ幅方向への広がり・サイド起点の有無" },
  { id: "pressIntensity", label: "プレッシング強度", description: "FWとDFのライン間の狭さ（コンパクトさ）" },
];
