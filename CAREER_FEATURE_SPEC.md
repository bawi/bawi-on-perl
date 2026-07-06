# Career Feature Implementation Specification

## Overview

This document specifies the implementation of a separate career tracking feature for the Bawi BBS system, splitting the current combined 학위/경력 (degree/career) system into two distinct features: academic degrees and professional career experience.

## Current System Limitations

### Database Schema Issues
- `bw_user_degree.type` enum is hardcoded for academic degrees only
- `schools` table contains only academic institutions (177 entries)
- Fields like "advisors" and "research content" are academic-specific
- Manual admin intervention required for adding new institutions

### User Experience Issues
- Corporate career experience forced into academic degree framework
- Limited career types (only academic positions)
- No support for company hierarchies or job positions
- Synonym management for organization names not supported

## Proposed Solution

### New Database Schema

```sql
CREATE TABLE `bw_user_career` (
  `career_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `type` enum('employment','internship','volunteer','research','military','other') NOT NULL DEFAULT 'employment',
  `organization_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `position` varchar(255) NOT NULL DEFAULT '',
  `department` varchar(255) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  `start_date` date NOT NULL DEFAULT '0000-00-00',
  `end_date` date NOT NULL DEFAULT '0000-00-00',
  `status` varchar(20) NOT NULL,
  `is_current` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`career_id`),
  KEY `uid` (`uid`),
  KEY `organization_id` (`organization_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `organizations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(128) NOT NULL DEFAULT '',
  `brief_name` varchar(32) NOT NULL DEFAULT '',
  `type` enum('company','government','nonprofit','academic','hospital','other') NOT NULL DEFAULT 'company',
  `url` varchar(64) DEFAULT NULL,
  `country_code` varchar(2) NOT NULL DEFAULT 'KR',
  `verified` tinyint(1) DEFAULT 0,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `created_by` mediumint(8) unsigned DEFAULT NULL,
  `created_date` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `full_name` (`full_name`),
  KEY `brief_name` (`brief_name`),
  KEY `type` (`type`),
  KEY `verified` (`verified`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
```

## **CRITICAL: Stealth Implementation Strategy**

### Production Safety Requirements

**⚠️ NO TEST SERVER AVAILABLE - PRODUCTION-ONLY DEPLOYMENT**

Since this is a live production system with no separate test environment, implementation must follow a **stealth rollout approach**:

1. **Hidden URL Testing Phase**
   - Create parallel files with `_beta` or `_v2` suffixes
   - Example: `career_beta.cgi`, `profile_v2.cgi`
   - Access only through direct URLs (not linked from main navigation)
   - Test with limited known users only

2. **Gradual Feature Exposure**
   - Phase 1: Admin-only access via direct URLs
   - Phase 2: Selected beta users via manual URL sharing
   - Phase 3: Optional feature flag in user preferences
   - Phase 4: Full rollout with navigation integration

3. **Atomic Swap Strategy**
   - Prepare all new files completely in parallel
   - Test thoroughly in stealth mode
   - Single deployment moment: rename files to replace originals
   - Immediate rollback plan available

### Implementation Phases

#### Phase 1: Stealth Infrastructure (Week 1)
**Files to create (hidden from navigation):**
- `/user/career_beta.cgi` - Career management (clone of degree.cgi)
- `/user/skin/default/career_beta.tmpl` - Career form template
- `/user/organization_beta.cgi` - Organization browsing
- `/user/skin/default/organization_beta.tmpl` - Organization listing
- `/user/profile_v2.cgi` - Enhanced profile with both degrees and career
- `/user/skin/default/profile_v2.tmpl` - New profile template

**Database changes:**
- Create new tables with `_beta` suffix initially
- Test data migration scripts

**Perl module extensions:**
- Add career methods to `Bawi::User` with feature flags
- Backward compatibility maintained

#### Phase 2: Admin Tools (Week 2)
**Stealth admin interface:**
- `/admin/organizations_beta.cgi` - Organization management
- `/admin/career_admin_beta.cgi` - Career data oversight
- User-submitted organization approval workflow

#### Phase 3: Beta Testing (Week 3)
**Limited user testing:**
- Direct URL access for selected users
- Feedback collection mechanism
- Bug fixes and refinements
- Performance monitoring

#### Phase 4: Production Swap (Week 4)
**Atomic deployment:**
```bash
# Backup current files
cp degree.cgi degree.cgi.backup
cp profile.cgi profile.cgi.backup

# Atomic swap
mv career_beta.cgi career.cgi
mv profile_v2.cgi profile.cgi
mv organization_beta.cgi organization.cgi

# Update navigation templates
# Enable production database tables
```

## Technical Specifications

### New Files Required

| File | Purpose | Base Template | Lines Est. |
|------|---------|---------------|------------|
| `/user/career.cgi` | Career CRUD operations | `degree.cgi` | ~120 |
| `/user/skin/default/career.tmpl` | Career form UI | `degree.tmpl` | ~150 |
| `/user/organization.cgi` | Organization browsing | `school.cgi` | ~130 |
| `/user/skin/default/organization.tmpl` | Organization listing | `school.tmpl` | ~100 |
| `/admin/organizations.cgi` | Org management | New | ~200 |
| `/admin/skin/default/organizations.tmpl` | Admin UI | New | ~150 |

### Perl Module Extensions (`/lib/Bawi/User.pm`)

```perl
# Career management methods (add ~200 lines)
sub get_career($)
sub add_career(@)
sub update_career($@)
sub del_career($$)
sub career_set($)
sub organization_list(%)
sub add_organization(@)
sub merge_organizations($$)
```

### Key Features

#### User-Facing Features
- **Career Types**: Employment, Internship, Volunteer, Research, Military, Other
- **Organization Management**: User can suggest new organizations
- **Timeline View**: Chronological career progression
- **Current Position**: Flag for ongoing employment
- **Privacy Controls**: Show/hide specific career entries

#### Admin Features
- **Organization Approval**: Review user-submitted organizations
- **Duplicate Detection**: Find potential organization duplicates
- **Merge Tool**: Combine duplicate organization entries
- **Verification Status**: Mark trusted organizations
- **Bulk Operations**: Import/export organization data

### Data Migration Strategy

```sql
-- Create migration script to split existing degree data
-- Identify career-like entries in bw_user_degree
-- Move non-academic entries to new career system
-- Preserve academic degrees in original system
```

## Testing Checklist

### Stealth Phase Testing
- [ ] Direct URL access works without navigation links
- [ ] Database operations don't interfere with production data
- [ ] Backward compatibility maintained
- [ ] Error handling for missing organizations
- [ ] User permission checks work correctly

### Integration Testing
- [ ] Profile page shows both degrees and career correctly
- [ ] Search functionality includes career data
- [ ] User edit flow handles both systems
- [ ] Admin tools work with new data structures

### Production Readiness
- [ ] Performance impact assessment
- [ ] Database migration tested with production data copy
- [ ] Rollback procedures verified
- [ ] User documentation prepared
- [ ] Admin training completed

## Risk Mitigation

### Rollback Plan
1. **Immediate rollback**: Rename files back to originals
2. **Database rollback**: Disable new tables, restore original queries
3. **User communication**: Prepare explanation for any disruption

### Production Monitoring
- **Database performance**: Monitor query times on new tables
- **User feedback**: Track support requests related to new features
- **Error logging**: Enhanced logging for new career functionality

## Timeline Estimate

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1: Infrastructure | 1 week | Stealth career system, database schema |
| Phase 2: Admin Tools | 1 week | Organization management, approval workflow |
| Phase 3: Beta Testing | 1 week | User testing, bug fixes, refinements |
| Phase 4: Production Deploy | 3 days | Atomic swap, monitoring, support |

**Total: 3-4 weeks with stealth approach**

## Search System Integration

### Current Search Infrastructure Analysis

The Bawi system has multiple search interfaces that need career feature integration:

#### 1. Main Search (`/main/search.cgi` & `/main/search2.cgi`)
**Current capabilities:**
- **People search**: Searches `bw_xauth_passwd`, `bw_user_ki`, `bw_user_basic` tables
- **Search fields**: id, name, affiliation, addresses, phone numbers
- **Article search**: Full-text search on board posts (search2.cgi only)
- **Board search**: Searches board titles and creators

**Integration requirements:**
- Add organization name and position to people search results
- Search career history data alongside academic data
- Extend search fields to include `organizations.full_name`, `bw_user_career.position`

#### 2. User-Specific Search (`/user/search.cgi`)
**Current capabilities:**
- **Affiliation search**: Uses `search_affiliation()` method in `Bawi::User`
- **Highlight matching text**: CSS highlighting for search terms
- **Simple keyword-based search**: Basic pattern matching

**Integration requirements:**
- Extend to search organization names and career positions
- Create parallel `search_career()` method
- Add career-specific search UI with organization filtering

#### 3. School/Organization Browsing (`/user/school.cgi`)
**Current capabilities:**
- **School statistics**: Counts users by degree type and school
- **User listing by school**: Shows all users from specific institution
- **Advisor search**: Groups users by advisor names

**New parallel system needed:**
- **`/user/organization.cgi`**: Browse users by organization
- **Career statistics**: Show user counts by organization and position type
- **Position/department search**: Similar to advisor grouping

### Search Integration Implementation Plan

#### Phase 1: Database Search Extensions (Stealth)

**New search methods in `Bawi::User.pm`:**
```perl
# Career-specific search (parallel to search_affiliation)
sub search_career {
    my ($self, $keyword) = @_;
    my $sql = qq(select a.id, a.name, b.ki, c.position, d.full_name as organization
                 from bw_xauth_passwd as a, bw_user_ki as b, 
                      bw_user_career as c, organizations as d
                 where a.uid=b.uid && a.uid=c.uid && c.organization_id=d.id &&
                 (c.position like ? || d.full_name like ? || d.brief_name like ? ||
                  a.id like ? || a.name like ?));
    my $rv = $DBH->selectall_hashref($sql, 'id', undef, ("\%$keyword\%") x 5);
    # Sort and return logic similar to existing search_affiliation
}

# Enhanced people search (combines academic + career)
sub search_people_enhanced {
    my ($self, $keyword) = @_;
    # Union query combining degree/school data and career/organization data
    # Returns unified profile with both academic and professional background
}

# Organization statistics (parallel to school statistics in school.cgi)
sub organization_stats {
    my ($self, $type) = @_;
    my $sql = qq(select a.full_name as organization, a.id, count(*) as count
                 from organizations as a, bw_user_career as b 
                 where a.id=b.organization_id && b.type=? 
                 group by a.id order by count desc, organization);
    # Similar logic to degree_stat() in school.cgi
}
```

#### Phase 2: Search UI Extensions (Stealth)

**Enhanced search templates:**
- **`/main/skin/default/search_beta.tmpl`**: Add career search option
- **`/user/skin/default/search_beta.tmpl`**: Career-specific search interface
- **`/user/skin/default/organization_beta.tmpl`**: Organization browsing (clone of school.tmpl)

**New search categories:**
- **People by Academic Background**: Current functionality
- **People by Career Background**: New career-based search
- **People by Organization**: Browse by company/institution
- **Combined Profile Search**: Search across both academic and career data

#### Phase 3: Search Integration (Stealth)

**Enhanced main search (`/main/search_beta.cgi`):**
```perl
# Add career search type
if ($type eq 'career') {
    $ui->tparam(result_career=>&search_career($keyword, $ui));
} elsif ($type eq 'people_enhanced') {
    $ui->tparam(result_people=>&search_people_enhanced($keyword, $ui));
}
```

**Enhanced user search (`/user/search_beta.cgi`):**
```perl
# Support multiple search modes
my $search_type = $ui->cparam('search_type') || 'affiliation';
if ($search_type eq 'career') {
    my $rv = $user->search_career($keyword);
    # Apply highlighting and formatting
} elsif ($search_type eq 'organization') {
    my $rv = $user->search_organization($keyword);
}
```

#### Phase 4: Production Search Migration

**Atomic search system upgrade:**
1. **Backup existing search files**
2. **Deploy enhanced search with backward compatibility**
3. **Gradual rollout through feature flags**
4. **Full search integration activation**

### Search Feature Specifications

#### Enhanced People Search Results
**Current format:**
```
[기수] 이름(ID): 소속, 전화번호
```

**Enhanced format:**
```
[기수] 이름(ID): 
  Academic: [학위] 학교명, 학과
  Career: [직급] 회사명, 부서 [기간]
  Contact: 전화번호
```

#### Organization Search Interface
**Search filters:**
- **Organization type**: Company, Government, Academic, Hospital, etc.
- **Position level**: Entry, Manager, Director, Executive
- **Career period**: Current, Past, Date range
- **Location**: By country/region

**Search results:**
- **Organization profile**: Name, type, verified status
- **User count**: Number of users with experience
- **Popular positions**: Most common job titles
- **Related organizations**: Parent/subsidiary companies

### Performance Considerations

#### Database Indexing
```sql
-- Career search optimization
ALTER TABLE bw_user_career ADD INDEX idx_search (organization_id, position, uid);
ALTER TABLE organizations ADD INDEX idx_name_search (full_name, brief_name);
ALTER TABLE organizations ADD FULLTEXT INDEX ft_names (full_name, brief_name);

-- Combined search optimization  
ALTER TABLE bw_user_career ADD INDEX idx_user_current (uid, is_current, end_date);
```

#### Caching Strategy
- **Organization autocomplete**: Cache popular organization names
- **Search result caching**: Cache frequent search queries
- **Statistics caching**: Cache organization/position statistics

### Search Migration Timeline

| Week | Search Component | Status |
|------|------------------|--------|
| Week 1 | Database methods + basic career search | Stealth development |
| Week 2 | Enhanced UI templates + organization browsing | Stealth testing |
| Week 3 | Integration testing + performance optimization | Beta user testing |
| Week 4 | Production search deployment | Atomic migration |

## Success Metrics

- Zero production downtime during deployment
- Successful data migration without loss
- User adoption rate of new career features
- Reduction in admin overhead for organization management
- Improved user profile completeness
- **Enhanced search functionality**: Career-based user discovery
- **Organization network analysis**: Company/institution relationship mapping

---

**Document Version**: 1.1  
**Created**: 2025-07-24  
**Updated**: 2025-07-24 (Added Search Integration)  
**Status**: Specification Phase