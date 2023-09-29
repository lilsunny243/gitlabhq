export const mockAbuseReport = {
  user: {
    username: 'spamuser417',
    name: 'Sp4m User',
    createdAt: '2023-03-29T09:30:23.885Z',
    email: 'sp4m@spam.com',
    lastActivityOn: '2023-04-02',
    avatarUrl: 'https://www.gravatar.com/avatar/a2579caffc69ea5d7606f9dd9d8504ba?s=80&d=identicon',
    path: '/spamuser417',
    adminPath: '/admin/users/spamuser417',
    plan: 'Free',
    verificationState: { email: true, phone: false, creditCard: true },
    creditCard: {
      name: 'S. User',
      similarRecordsCount: 2,
      cardMatchesLink: '/admin/users/spamuser417/card_match',
    },
    pastClosedReports: [
      {
        category: 'offensive',
        createdAt: '2023-02-28T10:09:54.982Z',
        reportPath: '/admin/abuse_reports/29',
      },
      {
        category: 'crypto',
        createdAt: '2023-03-31T11:57:11.849Z',
        reportPath: '/admin/abuse_reports/31',
      },
    ],
    mostUsedIp: null,
    lastSignInIp: '::1',
    snippetsCount: 0,
    groupsCount: 0,
    notesCount: 6,
    similarOpenReports: [
      {
        status: 'open',
        message: 'This is obvious spam',
        reportedAt: '2023-03-29T09:39:50.502Z',
        category: 'spam',
        type: 'issue',
        content: '',
        screenshot: null,
        reporter: {
          username: 'reporter 2',
          name: 'Another Reporter',
          avatarUrl: 'https://www.gravatar.com/avatar/anotherreporter',
          path: '/reporter-2',
        },
        updatePath: '/admin/abuse_reports/28',
      },
    ],
  },
  report: {
    globalId: 'gid://gitlab/AbuseReport/1',
    status: 'open',
    message: 'This is obvious spam',
    reportedAt: '2023-03-29T09:39:50.502Z',
    category: 'spam',
    type: 'comment',
    content:
      '<p data-sourcepos="1:1-1:772" dir="auto">Farmers Toy Sale ON NOW | SHOP CATALOGUE ... 50% off Kids\' Underwear by Hanes ... BUY 1 GET 1 HALF PRICE on Women\'s Clothing by Whistle, Ella Clothing Farmers Toy Sale ON <a href="http://www.farmers.com" rel="nofollow noreferrer noopener" target="_blank">www.farmers.com</a> | SHOP CATALOGUE ... 50% off Kids\' Underwear by Hanes ... BUY 1 GET 1 HALF PRICE on Women\'s Clothing by Whistle, Ella Clothing Farmers Toy Sale ON NOW | SHOP CATALOGUE ... 50% off Kids\' Underwear by Farmers Toy Sale ON NOW | SHOP CATALOGUE ... 50% off Kids\' Underwear by Hanes ... BUY 1 GET 1 HALF PRICE on Women\'s Clothing by Whistle, Ella Clothing Farmers Toy Sale ON <a href="http://www.farmers.com" rel="nofollow noreferrer noopener" target="_blank">www.farmers.com</a> | SHOP CATALOGUE ... 50% off Kids\' Underwear by Hanes ... BUY 1 GET 1 HALF PRICE on Women\'s Clothing by Whistle, Ella Clothing Farmers Toy Sale ON NOW | SHOP CATALOGUE ... 50% off Kids\' Underwear by.</p>',
    url: 'http://localhost:3000/spamuser417/project/-/merge_requests/1#note_1375',
    screenshot:
      '/uploads/-/system/abuse_report/screenshot/27/Screenshot_2023-03-30_at_16.56.37.png',
    updatePath: '/admin/abuse_reports/27',
    moderateUserPath: '/admin/abuse_reports/27/moderate_user',
    reporter: {
      username: 'reporter',
      name: 'R Porter',
      avatarUrl:
        'https://www.gravatar.com/avatar/a2579caffc69ea5d7606f9dd9d8504ba?s=80&d=identicon',
      path: '/reporter',
    },
  },
};

export const mockLabel1 = {
  id: 'gid://gitlab/Admin::AbuseReportLabel/1',
  title: 'Uno',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockLabel2 = {
  id: 'gid://gitlab/Admin::AbuseReportLabel/2',
  title: 'Dos',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockLabelsQueryResponse = {
  data: {
    labels: {
      nodes: [mockLabel1, mockLabel2],
      __typename: 'LabelConnection',
    },
  },
};

export const mockReportQueryResponse = {
  data: {
    abuseReport: {
      labels: {
        nodes: [mockLabel1],
        __typename: 'LabelConnection',
      },
      __typename: 'AbuseReport',
    },
  },
};

export const mockCreateLabelResponse = {
  data: {
    labelCreate: {
      label: {
        id: 'gid://gitlab/Admin::AbuseReportLabel/1',
        color: '#ed9121',
        description: null,
        title: 'abuse report label',
        textColor: '#FFFFFF',
        __typename: 'Label',
      },
      errors: [],
      __typename: 'AbuseReportLabelCreatePayload',
    },
  },
};
