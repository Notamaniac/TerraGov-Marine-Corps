import { Box, Button, LabeledList, Section, Stack } from 'tgui-core/components';
import { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Channel = {
  name: string;
  on: BooleanLike;
};

type BorgRadioData = {
  channels: Channel[];
  default_channel: string;
  common: string;
};

export const BorgRadio = (props) => {
  const { act, data } = useBackend<BorgRadioData>();
  const { channels, default_channel, common } = data;
  return (
    <Window width={360} height={480}>
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Section title="Default channel">
              <Box color="label" mb={1}>
                Where a message starting with ; is sent.
              </Box>
              <Button
                fluid
                selected={default_channel === common}
                onClick={() => act('set_default', { channel: common })}
              >
                {common}
              </Button>
              {channels
                .filter((channel) => !!channel.on)
                .map((channel) => (
                  <Button
                    fluid
                    key={channel.name}
                    selected={default_channel === channel.name}
                    onClick={() =>
                      act('set_default', { channel: channel.name })
                    }
                  >
                    {channel.name}
                  </Button>
                ))}
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section
              title="Channels"
              buttons={
                <>
                  <Button onClick={() => act('all_channels', { on: 1 })}>
                    All on
                  </Button>
                  <Button onClick={() => act('all_channels', { on: 0 })}>
                    All off
                  </Button>
                </>
              }
            >
              {channels.length ? (
                <LabeledList>
                  {channels.map((channel) => (
                    <LabeledList.Item key={channel.name} label={channel.name}>
                      <Button
                        icon={channel.on ? 'volume-up' : 'volume-mute'}
                        color={channel.on ? 'good' : 'bad'}
                        onClick={() =>
                          act('toggle_channel', { channel: channel.name })
                        }
                      >
                        {channel.on ? 'On' : 'Off'}
                      </Button>
                    </LabeledList.Item>
                  ))}
                </LabeledList>
              ) : (
                <Box color="label">No channels available.</Box>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
