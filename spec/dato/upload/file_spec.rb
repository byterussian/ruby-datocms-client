# frozen_string_literal: true
require 'spec_helper'

module Dato
  module Upload
    describe File, :vcr do
      let(:account_client) do
        Dato::Account::Client.new(
          'XXX',
          base_url: 'http://account-api.lvh.me:3001'
        )
      end

      let(:site) do
        account_client.sites.create(name: 'Test site')
      end

      before do
        site
      end

      after do
        account_client.sites.destroy(site[:id])
      end

      let(:site_client) do
        Dato::Site::Client.new(
          site[:readwrite_token],
          base_url: 'http://site-api.lvh.me:3001'
        )
      end

      subject(:command) do
        described_class.new(site_client, source)
      end

      context 'with a url' do
        let(:source) { 'https://s3.claudiaraddi.net/slideshows/original/4/Sito2.jpg' }

        it 'downloads locally and then uploads the file' do
          expect(command.upload[:path]).to include('sito2.jpg')
          expect(command.upload[:size]).to eq(713_012)
          expect(command.upload[:format]).to eq('jpg')
        end
      end

      context 'with a local file' do
        let(:source) { './spec/fixtures/image.jpg' }

        it 'uploads the file' do
          expect(command.upload[:path]).to include('image.jpg')
          expect(command.upload[:size]).to eq(4_865)
          expect(command.upload[:format]).to eq('jpg')
        end
      end
    end
  end
end
