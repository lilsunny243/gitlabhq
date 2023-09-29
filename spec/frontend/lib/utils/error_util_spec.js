import {
  ActiveModelError,
  generateHelpTextWithLinks,
  mapSystemToFriendlyError,
} from '~/lib/utils/error_utils';
import { convertObjectPropsToLowerCase } from '~/lib/utils/common_utils';

describe('Error Alert Utils', () => {
  const unfriendlyErrorOneKey = 'Unfriendly error 1';
  const emailTakenAttributeMap = 'email:taken';
  const emailTakenError = 'Email has already been taken';
  const emailTakenFriendlyError = {
    message: 'This is a friendly error message for the given attribute map',
    links: {},
  };

  const mockErrorDictionary = convertObjectPropsToLowerCase({
    [unfriendlyErrorOneKey]: {
      message:
        'This is a friendly error with %{linkOneStart}link 1%{linkOneEnd} and %{linkTwoStart}link 2%{linkTwoEnd}',
      links: {
        linkOne: '/sample/link/1',
        linkTwo: '/sample/link/2',
      },
    },
    'Unfriendly error 2': {
      message: 'This is a friendly error with only %{linkStart} one link %{linkEnd}',
      links: {
        link: '/sample/link/1',
      },
    },
    'Unfriendly error 3': {
      message: 'This is a friendly error with no links',
      links: {},
    },
    [emailTakenAttributeMap]: emailTakenFriendlyError,
    [emailTakenError]: emailTakenFriendlyError,
  });

  const mockGeneralError = {
    message: 'Something went wrong',
    link: {},
  };

  describe('mapSystemToFriendlyError', () => {
    describe.each(Object.keys(mockErrorDictionary))('when system error is %s', (systemError) => {
      const friendlyError = mockErrorDictionary[systemError];

      it('maps the system error to the friendly one', () => {
        expect(mapSystemToFriendlyError(new Error(systemError), mockErrorDictionary)).toEqual(
          friendlyError,
        );
      });

      it('maps the system error to the friendly one from uppercase', () => {
        expect(
          mapSystemToFriendlyError(new Error(systemError.toUpperCase()), mockErrorDictionary),
        ).toEqual(friendlyError);
      });
    });

    describe.each(['', {}, [], undefined, null, new Error()])(
      'when system error is %s',
      (systemError) => {
        it('defaults to the given general error message when provided', () => {
          expect(
            mapSystemToFriendlyError(systemError, mockErrorDictionary, mockGeneralError),
          ).toEqual(mockGeneralError);
        });

        it('defaults to the default error message when general error message is not provided', () => {
          expect(mapSystemToFriendlyError(systemError, mockErrorDictionary)).toEqual({
            message: 'Something went wrong. Please try again.',
            links: {},
          });
        });
      },
    );

    describe('when system error is a non-existent key', () => {
      const message = 'a non-existent key';
      const nonExistentKeyError = { message, links: {} };

      it('maps the system error to the friendly one', () => {
        expect(mapSystemToFriendlyError(new Error(message), mockErrorDictionary)).toEqual(
          nonExistentKeyError,
        );
      });
    });

    describe('when system error consists of multiple non-existent keys', () => {
      const message = 'a non-existent key, another non-existent key';
      const nonExistentKeyError = { message, links: {} };

      it('maps the system error to the friendly one', () => {
        expect(mapSystemToFriendlyError(new Error(message), mockErrorDictionary)).toEqual(
          nonExistentKeyError,
        );
      });
    });

    describe('when system error consists of multiple messages with one matching key', () => {
      const message = `a non-existent key, ${unfriendlyErrorOneKey}`;

      it('maps the system error to the friendly one', () => {
        expect(mapSystemToFriendlyError(new Error(message), mockErrorDictionary)).toEqual(
          mockErrorDictionary[unfriendlyErrorOneKey.toLowerCase()],
        );
      });
    });

    describe('when error is email:taken error_attribute_map', () => {
      const errorAttributeMap = { email: ['taken'] };

      it('maps the email friendly error', () => {
        expect(
          mapSystemToFriendlyError(
            new ActiveModelError(errorAttributeMap, emailTakenError),
            mockErrorDictionary,
          ),
        ).toEqual(mockErrorDictionary[emailTakenAttributeMap.toLowerCase()]);
      });
    });

    describe('when there are multiple errors in the error_attribute_map', () => {
      const errorAttributeMap = { email: ['taken', 'invalid'] };

      it('maps the email friendly error', () => {
        expect(
          mapSystemToFriendlyError(
            new ActiveModelError(errorAttributeMap, `${emailTakenError}, Email is invalid`),
            mockErrorDictionary,
          ),
        ).toEqual(mockErrorDictionary[emailTakenAttributeMap.toLowerCase()]);
      });
    });
  });

  describe('generateHelpTextWithLinks', () => {
    describe('when the error is present in the dictionary', () => {
      describe.each(Object.values(mockErrorDictionary))(
        'when system error is %s',
        (friendlyError) => {
          it('generates the proper link', () => {
            const errorHtmlString = generateHelpTextWithLinks(friendlyError);
            const expected = Array.from(friendlyError.message.matchAll(/%{/g)).length / 2;
            const newNode = document.createElement('div');
            newNode.innerHTML = errorHtmlString;
            const links = Array.from(newNode.querySelectorAll('a'));

            expect(links).toHaveLength(expected);
          });
        },
      );
    });

    describe('when the error contains no links', () => {
      it('generates the proper link/s', () => {
        const anError = { message: 'An error', links: {} };
        const errorHtmlString = generateHelpTextWithLinks(anError);
        const expected = Object.keys(anError.links).length;
        const newNode = document.createElement('div');
        newNode.innerHTML = errorHtmlString;
        const links = Array.from(newNode.querySelectorAll('a'));

        expect(links).toHaveLength(expected);
      });
    });

    describe('when the error is invalid', () => {
      it('returns the error', () => {
        expect(() => generateHelpTextWithLinks([])).toThrow(
          new Error('The error cannot be empty.'),
        );
      });
    });

    describe('when the error is not an object', () => {
      it('returns the error', () => {
        const errorHtmlString = generateHelpTextWithLinks('An error');

        expect(errorHtmlString).toBe('An error');
      });
    });

    describe('when the error is falsy', () => {
      it('throws an error', () => {
        expect(() => generateHelpTextWithLinks(null)).toThrow(
          new Error('The error cannot be empty.'),
        );
      });
    });
  });
});
