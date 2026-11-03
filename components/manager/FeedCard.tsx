import { StyleSheet, Text, View } from 'react-native';
import { MapPin } from 'lucide-react-native';
import { OpeningSchema } from '@/components/OpeningSchema';
import { colors, radius, spacing } from '@/constants/theme';
import { formatDimensions, type FeedItem } from '@/lib/measurements/feed';
import { formatDate, getSideLabel, textOrNotSpecified } from '@/lib/measurements/format';

const SCHEMA_WIDTH = 150;

type Props = {
  item: FeedItem;
};

export function FeedCard({ item }: Props) {
  const { measurement, opening } = item;

  return (
    <View style={styles.card}>
      <View style={styles.details}>
        <View style={styles.headerRow}>
          <Text style={styles.client} numberOfLines={1}>
            {textOrNotSpecified(measurement.clientName)}
          </Text>
          <Text style={styles.date}>{formatDate(measurement.createdAt)}</Text>
        </View>

        <View style={styles.addressRow}>
          <MapPin size={14} color={colors.textMuted} strokeWidth={2} />
          <Text style={styles.address}>{textOrNotSpecified(measurement.address)}</Text>
        </View>

        <View style={styles.metaGrid}>
          <Meta label="Этаж" value={textOrNotSpecified(opening?.floor ?? measurement.floor)} />
          <Meta label="Комната" value={textOrNotSpecified(opening?.room)} />
          <Meta label="Сторона открывания" value={getSideLabel(opening?.side ?? null)} />
          <Meta label="В × Ш × Т" value={formatDimensions(opening)} />
        </View>
      </View>

      <View style={styles.schema}>
        {opening ? (
          <OpeningSchema side={opening.side} width={SCHEMA_WIDTH} />
        ) : (
          <Text style={styles.noOpening}>Проемов пока нет</Text>
        )}
      </View>
    </View>
  );
}

type MetaProps = { label: string; value: string };

function Meta({ label, value }: MetaProps) {
  return (
    <View style={styles.meta}>
      <Text style={styles.metaLabel}>{label}</Text>
      <Text style={styles.metaValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radius.lg,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.borderSoft,
  },
  details: {
    flex: 1,
    minWidth: 0,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: spacing.xs,
  },
  client: {
    flex: 1,
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 19,
    color: colors.text,
  },
  date: {
    fontSize: 9,
    color: colors.textMuted,
  },
  addressRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 4,
  },
  address: {
    flex: 1,
    fontSize: 11,
    lineHeight: 16,
    color: colors.textSecondary,
  },
  metaGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: spacing.xs,
    gap: spacing.xs,
  },
  meta: {
    minWidth: 120,
    flexGrow: 1,
    padding: spacing.xs,
    borderRadius: radius.sm,
    backgroundColor: colors.background,
  },
  metaLabel: {
    fontSize: 8,
    fontWeight: '600',
    color: colors.textMuted,
    textTransform: 'uppercase',
  },
  metaValue: {
    marginTop: 2,
    fontSize: 11,
    fontWeight: '600',
    color: colors.text,
  },
  schema: {
    width: SCHEMA_WIDTH,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xs,
    borderRadius: radius.md,
    backgroundColor: colors.background,
  },
  noOpening: {
    fontSize: 9,
    color: colors.textMuted,
    textAlign: 'center',
  },
});
