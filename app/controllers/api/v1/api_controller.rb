module Api::V1
  class ApiController < ApplicationController
    include Swagger::Docs::ImpotentMethods

    class << self
      Swagger::Docs::Generator::set_real_methods

      def inherited(subclass)
        super
        except_classes = [
          'Api::V1::AttendeesController',
          'Api::V1::AlbumsController',
          'Api::V1::ProfileController',
          'Api::V1::GenresController',
          'Api::V1::Shopping::CategoriesController',
          'Api::V1::SettingsController',
        ]
        unless except_classes.include?(subclass.name)
          subclass.class_eval do
            setup_basic_api_documentation
          end
        end
      end

      def setup_authorization_header(api_action)
        swagger_api api_action do
          param :header, 'Authorization', :string, :required, 'Authentication token'
        end
      end

      private
      def setup_basic_api_documentation
        [:index, :show, :create, :update, :destroy].each do |api_action|
          setup_authorization_header(api_action)
        end
      end
    end
  end
end
