import { open } from "@raycast/api";

export const OFFICIAL_SEND_TO_KINDLE_URL = "https://www.amazon.com/sendtokindle";

export async function openOfficialSendToKindle(): Promise<void> {
  await open(OFFICIAL_SEND_TO_KINDLE_URL);
}
