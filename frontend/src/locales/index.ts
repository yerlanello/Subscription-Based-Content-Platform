export { ru, type Translations } from "./ru";
export { en } from "./en";
export { kk } from "./kk";

import { ru } from "./ru";
import { en } from "./en";
import { kk } from "./kk";

export type Locale = "ru" | "en" | "kk";

export const translations: Record<Locale, typeof ru> = { ru, en, kk };
