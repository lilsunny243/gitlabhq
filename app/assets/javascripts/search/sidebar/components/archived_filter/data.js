import { s__ } from '~/locale';

const headerLabel = s__('GlobalSearch|Archived');
const checkboxLabel = s__('GlobalSearch|Include archived');
export const TRACKING_NAMESPACE = 'search:archived:select';
export const TRACKING_LABEL_CHECKBOX = 'checkbox';

const scopes = {
  PROJECTS: 'projects',
  ISSUES: 'issues',
  MERGE_REQUESTS: 'merge_requests',
  NOTES: 'notes',
  BLOBS: 'blobs',
  COMMITS: 'commits',
};

const filterParam = 'include_archived';

export const archivedFilterData = {
  headerLabel,
  checkboxLabel,
  scopes,
  filterParam,
};
