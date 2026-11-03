import { NOT_SPECIFIED } from './format';
import type { Measurement, Opening } from './types';

export type FeedItem = {
  key: string;
  measurement: Measurement;
  opening: Opening | null;
};

export function buildFeedItems(measurements: Measurement[]): FeedItem[] {
  return measurements.flatMap((measurement): FeedItem[] => {
    if (measurement.openings.length === 0) {
      return [{ key: measurement.id, measurement, opening: null }];
    }
    return measurement.openings.map((opening) => ({
      key: `${measurement.id}:${opening.id}`,
      measurement,
      opening,
    }));
  });
}

export function filterFeedItems(items: FeedItem[], query: string): FeedItem[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return items;
  return items.filter(
    ({ measurement }) =>
      measurement.address.toLowerCase().includes(needle) ||
      measurement.clientName.toLowerCase().includes(needle)
  );
}

export function formatDimensions(opening: Opening | null): string {
  if (!opening || opening.height === null || opening.width === null || opening.thickness === null) {
    return NOT_SPECIFIED;
  }
  return `${opening.height} × ${opening.width} × ${opening.thickness} мм`;
}
